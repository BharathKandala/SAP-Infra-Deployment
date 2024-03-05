#!/usr/bin/env bash
# Copyright (C) Microsoft Corporation. All rights reserved.

Constant()
{
	{
		Constant_Msawb_User="root"
		Constant_Msawb_Group="root"
		Constant_Msawb_Group_Secondary="msawb"
		Constant_Msawb_Home="/opt/msawb"
		Constant_Handler_Location="/var/lib/waagent"

		Constant_Plugin_Name="com-sap-hana"
		Constant_Plugin_Default_Backup_Key_Name="AZUREWLBACKUPHANAUSER"
		Constant_Plugin_Default_Backup_Key_User="AZUREWLBACKUPHANAUSER"
		Constant_Plugin_Min_Version_SAP_INTERNAL_HANA_SUPPORT_NOT_Required="2.00.046.00"
		Constant_Plugin_Min_Version_MDC_BACKUP_ADMIN_ROLE_Required="2.00.050.00"

		Constant_Plugin_Config_File="${Constant_Msawb_Home}/etc/plugins/${Constant_Plugin_Name}/{1}.config.json"
		Constant_Plugin_Config_File_Old="${Constant_Msawb_Home}/etc/config/SAPHana/config.json"

		Constant_Plugin_Environment_File="${Constant_Msawb_Home}/etc/config/SAPHana/msawb-pluginhost-saphana-{1}-environment.conf"

		Constant_Plugin_Host_Service_File="/usr/lib/systemd/system/msawb-pluginhost-${Constant_Plugin_Name}-{1}.service"
		Constant_Plugin_Host_Service_File_Old="/usr/lib/systemd/system/msawb-pluginhost-saphana-{1}.service"

		Constant_Script_Version="2.0.9.5"
		Constant_Script_Name="$(basename "${0}")"
		Constant_Script_Path="$(realpath "${0}")"
		Constant_Script_Directory="$(dirname "${Constant_Script_Path}")"
		Constant_Script_User="$(whoami)"
		Constant_Script_Log_File="${Constant_Msawb_Home}/var/log/plugins/${Constant_Plugin_Name}/config.$(date +%s).log"
		Constant_Script_Source_Url="https://aka.ms/scriptforpermsonhana"

		Constant_UserHints_SystemKeyCreationMsg="Please create a system key for the system user by running the following command as <sid>adm user\n\n\nfor the mdc machine-\nhdbuserstore set <SYSTEM KEY NAME> localhost:3<INSTANCE_NUMBER>13 SYSTEM '<PASSWORD FOR SYSTEM USER>'\nFor sdc machine -\nhdbuserstore set <SYSTEM KEY NAME> localhost:3<INSTANCE_NUMBER>15 SYSTEM '<PASSWORD FOR SYSTEM USER>'\n\n\nThis system key can be deleted after creation of backup user."
		Constant_PreRequisitesMsg="Refer to the prerequisites to get started with SAP HANA Backup using Azure - https://docs.microsoft.com/azure/backup/tutorial-backup-sap-hana-db#prerequisites ."
	}
}

Errno()
{
	{
		Errno_Success=0
		Errno_Success_Message="Done."

		Errno_Failure=1
		Errno_Failure_Message="{1}"

		Errno_Argument_Missing=2
		Errno_Argument_Missing_Message="Missing argument for '{1}': See '${Constant_Script_Name} --help' for more information."

		Errno_Argument_Unknown=3
		Errno_Argument_Unknown_Message="Unknown argument '{1}': See '${Constant_Script_Name} --help' for more information."

		Errno_Argument_Unexpected=4
		Errno_Argument_Unexpected_Message="Unexpected argument '{1}': See '${Constant_Script_Name} --help' for more information."
	}
}

Logger()
{
	{
		if [ "${Constant_Script_User}" == "${Constant_Msawb_User}" ]
		then
		{
			mkdir -p "$(dirname "${Constant_Script_Log_File}")"
			touch "${Constant_Script_Log_File}"
			chown -R "${Constant_Msawb_User}:${Constant_Msawb_Group}" "$(dirname "${Constant_Script_Log_File}")"
			exec 3> "${Constant_Script_Log_File}"
		}
		else
		{
			exec 3> "/dev/null"
		}
		fi
	}

	Logger.LogMessage()
	{
		echo -e "${1}[$(date -Iseconds)] ${@:2}\e[0m" >&2
		echo "[$(date -Iseconds)] ${@:2}" >&3
	}

	Logger.LogError()
	{
		Logger.LogMessage "\e[1;31m" "[ERRO]" "${@}"
	}

	Logger.LogPass()
	{
		Logger.LogMessage "\e[1;32m" "[PASS]" "${@}"
	}

	Logger.LogWarning()
	{
		Logger.LogMessage "\e[1;33m" "[WARN]" "${@}"
	}

	Logger.LogInformation()
	{
		Logger.LogMessage "\e[1;37m" "[INFO]" "${@}"
	}

	Logger.Exit()
	{
		if [ "${#}" -eq 0 ]
		then
		{
			exec 3>&-
			exit 0
		}
		fi

		local errno="Errno_${1}"
		local message="Errno_${1}_Message"
		shift

		errno="${!errno}"
		message="${!message//\{1\}/${1}}"
		shift

		if [ "${errno}" -eq "0" ]
		then
		{
			Logger.LogMessage "\e[1;32m" "[SUCC]" "${message}"
		}
		else
		{
			Logger.LogMessage "\e[1;31m" "[FAIL]" "${message}" 
		}
		fi

		exec 3>&-
		exit "${errno}"
	}

	Logger.ExitOnArgumentMissing()
	{
		[ "${#}" -lt 2 ] && Logger.Exit Argument_Missing "${1}"
	}

	Logger.ExitOnArgumentUnexpected()
	{
		[ "${#}" -ne 0 ] && Logger.Exit Argument_Unexpected "${1}"
	}
}

Package()
{
	{
		Package_OS_Updated=0
		Package_OS_Name="$( (. /etc/os-release; echo "${ID^^}") | cut -d '_' -f1)"
		Package_OS_Version="$( (. /etc/os-release; echo "${VERSION_ID}") )"

		Package_SLES_Update_Command="echo -n"
		Package_SLES_Install_Command="zypper -n install {1}"
		Package_SLES_Version_Command="rpm -q --queryformat %{version} {1}"
		Package_SLES_Search_Command="rpm -qa {1}"

		Package_RHEL_Update_Command="echo -n"
		Package_RHEL_Install_Command="yum -y install {1}"
		Package_RHEL_Version_Command="rpm -q --queryformat %{version} {1}"
		Package_RHEL_Search_Command="rpm -qa {1}"

		Package_Python3_Executable="python3"
		Package_Python3_Version_Min="3.6.9"
		Package_Python3_Version_Rec="3.6.9"
		Package_Python3_SLES="python3"
		Package_Python3_RHEL="python3"
		Package_Python3_SLES_Upgrade="true"
		Package_Python3_RHEL_Upgrade="true"

		Package_Python2_Executable="python2.7"
		Package_Python2_Version_Min="2.7.5"
		Package_Python2_Version_Rec="2.7.13"
		Package_Python2_SLES="python2"
		Package_Python2_RHEL="python2"
		Package_Python2_SLES_Upgrade="true"
		Package_Python2_RHEL_Upgrade="true"

		Package_WaAgent_Executable="waagent"
		Package_WaAgent_Version_Min="2.2.18"
		Package_WaAgent_Version_Rec="2.2.36"
		Package_WaAgent_SLES="python-azure-agent"
		Package_WaAgent_RHEL="python-azure-agent"
		Package_WaAgent_SLES_Upgrade="true"
		Package_WaAgent_RHEL_Upgrade="true"

		Package_Curl_Executable="curl"
		Package_Curl_Version_Min="7.29.0"
		Package_Curl_Version_Rec="7.37.0"
		Package_Curl_SLES="curl"
		Package_Curl_RHEL="curl"
		Package_Curl_SLES_Upgrade="true"
		Package_Curl_RHEL_Upgrade="true"

		Package_UnixODBC_Executable="odbcinst"
		Package_UnixODBC_Version_Min="2.3.4"
		Package_UnixODBC_Version_Rec="2.3.6"
		Package_UnixODBC_SLES="unixODBC"
		Package_UnixODBC_RHEL="unixODBC"
		Package_UnixODBC_RHEL_Compat="compat-unixODBC234"
		Package_UnixODBC_SLES_Upgrade="true"
		Package_UnixODBC_RHEL_Upgrade="true"

		Package_Libicu_Version_Min="50.1.2"
		Package_Libicu_Version_Rec="50.1.2"
		Package_Libicu_RHEL="libicu"

		Package_PythonXML_Version_Min="2.7.17"
		Package_PythonXML_Version_Rec="2.7.17"
		Package_PythonXML_SLES="python-xml"

		Package_Unzip_Executable="unzip"
		Package_Unzip_Version_Min="6.0"
		Package_Unzip_Version_Rec="6.0"
		Package_Unzip_SLES="unzip"
		Package_Unzip_RHEL="unzip"
		Package_Unzip_SLES_Upgrade="true"
		Package_Unzip_RHEL_Upgrade="true"
	}

	Package.Update()
	{
		[ "${Package_OS_Updated}" -eq "1" ] && return
		Logger.LogInformation "Updating package catalog."
		local updateCommand="Package_${Package_OS_Name}_Update_Command"
		updateCommand="${!updateCommand}"
		eval "${updateCommand}"
		Logger.LogPass "Updated package catalog."
		Package_OS_Updated="1"
	}

	Package.VersionCompare()
	{
		"${Package_Python_Executable}" -c "from distutils.version import LooseVersion; exit(LooseVersion(\"${1}\") < LooseVersion(\"${2}\"))"
		Package_Version_Compare_Result="${?}"
	}

	Package.RequirePython()
	{
		case "${Package_OS_Name}" in
			"SLES")
			{
				case "${Package_OS_Version}" in
					"15" | "15.1" | "15.2")
					{
						Package_Python_Executable=${Package_Python3_Executable}
						Package.Require Python3
					};;
					*)
					{
						Package_Python_Executable=${Package_Python2_Executable}
						Package.Require Python2
					};;
				esac
			};;
			*)
			{
				Package_Python_Executable=${Package_Python2_Executable}
				Package.Require Python2
			};;
		esac
	}

	Package.RequireUnixODBC()
	{
		case "${Package_OS_Name}" in
			"RHEL")
			{
				case "${Package_OS_Version}" in
					"7.4" | "7.5" | "7.6" | "7.7" | "7.9")
					{
						Package_UnixODBC_RHEL=${Package_UnixODBC_RHEL_Compat}
						Package.Require UnixODBC
					};;
					*)
					{
						Package.Require UnixODBC
					};;
				esac
			};;
			*)
			{
				Package.Require UnixODBC
			};;
		esac
	}

	Package.RequireLibrary()
	{
		local libraryVersionMin="Package_${1}_Version_Min"
		libraryVersionMin="${!libraryVersionMin}"

		local libraryVersionRec="Package_${1}_Version_Rec"
		libraryVersionRec="${!libraryVersionRec}"

		local libraryName="Package_${1}_${Package_OS_Name}"
		libraryName="${!libraryName}"

		[ "x${libraryName}" == "x" ] && Logger.LogInformation "Ignoring installation of LIBRARY: '${1}' on Distro: '${Package_OS_Name}'" && return

		local installCommand="Package_${Package_OS_Name}_Install_Command"
		installCommand="${!installCommand//\{1\}/${libraryName}}"

		Logger.LogInformation "Checking for LIBRARY '${libraryName}' >= VERSION Minimum: '${libraryVersionMin}' Recommended: '${libraryVersionRec}'."

		local versionCommand="Package_${Package_OS_Name}_Version_Command"
		versionCommand="${!versionCommand//\{1\}/${libraryName}}"
		local libraryCurrentVersion="$(${versionCommand})"

		local searchCommand="Package_${Package_OS_Name}_Search_Command"
		searchCommand="${!searchCommand//\{1\}/${libraryName}}"
		local libraryExists="$(${searchCommand})"

		if [ "${libraryExists}" ]
		then
		{
			Package.VersionCompare "${libraryCurrentVersion}" "${libraryVersionRec}"
			if [ "${Package_Version_Compare_Result}" -eq "0" ]
			then
			{
				Logger.LogPass "Found VERSION = '${libraryCurrentVersion}': LIBRARY is up to date."
			}
			else
			{
				Logger.LogInformation "Found VERSION = '${libraryCurrentVersion}': Upgrading."
			}
			fi
		}
		else
		{
			Logger.LogInformation "Failed to determine VERSION: Not installed."
			Package_Version_Compare_Result=1
		}
		fi

		if [ "${Package_Version_Compare_Result}" -ne "0" ]
		then
		{
			Package.Update
			eval "${installCommand}"

			libraryCurrentVersion="$(${versionCommand})"
			libraryExists="$(${searchCommand})"
			[ ! "${libraryExists}" ] && Logger.Exit Failure "Failed to determine VERSION: Installation failed. Please add corresponding library repository for ${libraryName} to continue."
			
			Package.VersionCompare "${libraryCurrentVersion}" "${libraryVersionRec}"
			if [ "${Package_Version_Compare_Result}" -eq "0" ]
			then
			{
				Logger.LogPass "Found VERSION = '${libraryCurrentVersion}': LIBRARY is up to date."
			}
			else
			{
				Package.VersionCompare "${libraryCurrentVersion}" "${libraryVersionRec}"
				if [ "${Package_Version_Compare_Result}" -eq "0" ]
				then
				{
					Logger.LogWarning "Found VERSION = '${libraryCurrentVersion}': LIBRARY is old but compatible. Upgrade your distro or package repository for better support."
				}
				else
				{
					Logger.Exit Failure "Found VERSION = '${libraryCurrentVersion}': LIBRARY is too old to be compatible. Upgrade your distro or package repository to continue."
				}
				fi
			}
			fi
		}
		fi
	}

	Package.Require()
	{
		local isLibraryPackage=""
		[ "$#" -ge "2" ] && isLibraryPackage=${2}

		if [ "x${isLibraryPackage}" == "xtrue" ]
		then
		{
			Package.RequireLibrary ${1}
		}
		else
		{
			local executableName="Package_${1}_Executable"
			executableName="${!executableName}"

			local packageVersionMin="Package_${1}_Version_Min"
			packageVersionMin="${!packageVersionMin}"

			local packageVersionRec="Package_${1}_Version_Rec"
			packageVersionRec="${!packageVersionRec}"

			local packageName="Package_${1}_${Package_OS_Name}"
			packageName="${!packageName}"

			local doPackageUpgrade="Package_${1}_${Package_OS_Name}_Upgrade"
			doPackageUpgrade="${!doPackageUpgrade}"

			[ "x${packageName}" == "x" ] && Logger.LogInformation "Ignoring installation of PACKAGE: '${1}' on Distro: '${Package_OS_Name}'" && return

			local installCommand="Package_${Package_OS_Name}_Install_Command"
			installCommand="${!installCommand//\{1\}/${packageName}}"

			Logger.LogInformation "Checking for PACKAGE '${packageName}' >= VERSION Minimum: '${packageVersionMin}' Recommended: '${packageVersionRec}'."
			local packageCurrentVersion="0"
			local executablePath="$(which "${executableName}" 2> /dev/null)"

			if [ "x${executablePath}" != "x" ]
			then
			{
				packageCurrentVersion="$(${executablePath} --version 2>&1 | tr -s '[:space:]-' ' ' | cut -d ' ' -f 2)"
				if [ "x${doPackageUpgrade}" == "xfalse" ]
				then
				{
					Package.VersionCompare "${packageCurrentVersion}" "${packageVersionMin}"
					if [ "${Package_Version_Compare_Result}" -eq "0" ]
					then
					{
						Logger.LogPass "Found VERSION = '${packageCurrentVersion}': PACKAGE is old but compatible. Upgrade your distro or package repository for better support."
					}
					else
					{
						Logger.Exit Failure "Found VERSION = '${packageCurrentVersion}': PACKAGE is too old to be compatible. Upgrade your distro or package repository to continue."
					}
					fi
				}
				else
				{
					Package.VersionCompare "${packageCurrentVersion}" "${packageVersionRec}"
					if [ "${Package_Version_Compare_Result}" -eq "0" ]
					then
					{
						Logger.LogPass "Found VERSION = '${packageCurrentVersion}': PACKAGE is up to date."
					}
					else
					{
						Logger.LogInformation "Found VERSION = '${packageCurrentVersion}': Upgrading."
					}
					fi
				}
				fi
			}
			else
			{
				Logger.LogInformation "Failed to determine VERSION: Not installed."
				Package_Version_Compare_Result=1
			}
			fi

			if [ "${Package_Version_Compare_Result}" -ne "0" ]
			then
			{
				Package.Update
				eval "${installCommand}"

				executablePath="$(which "${executableName}" 2> /dev/null)"
				[ "x${executablePath}" == "x" ] && Logger.Exit Failure "Failed to determine VERSION: Installation failed. Please add corresponding package repository for ${packageName} to continue."

				packageCurrentVersion="$(${executablePath} --version 2>&1 | tr -s '[:space:]-' ' ' | cut -d ' ' -f 2)"
				Package.VersionCompare "${packageCurrentVersion}" "${packageVersionRec}"
				if [ "${Package_Version_Compare_Result}" -eq "0" ]
				then
				{
					Logger.LogPass "Found VERSION = '${packageCurrentVersion}': PACKAGE is up to date."
				}
				else
				{
					Package.VersionCompare "${packageCurrentVersion}" "${packageVersionMin}"
					if [ "${Package_Version_Compare_Result}" -eq "0" ]
					then
					{
						Logger.LogWarning "Found VERSION = '${packageCurrentVersion}': PACKAGE is old but compatible. Upgrade your distro or package repository for better support."
					}
					else
					{
						Logger.Exit Failure "Found VERSION = '${packageCurrentVersion}': PACKAGE is too old to be compatible. Upgrade your distro or package repository to continue."
					}
					fi
				}
				fi
			}
			fi
		}
		fi
	}
}

Check()
{
	{
		echo -n
	}

	Check.User()
	{
		Logger.LogInformation "Checking if '${Constant_Msawb_User}'."
		[ "x${Constant_Script_User}" != "x${Constant_Msawb_User}" ] && Logger.Exit Failure "Please re-run as '${Constant_Msawb_User}'."
		Logger.LogPass "Running as '${Constant_Msawb_User}'."
	}

	Check.OS()
	{
		Logger.LogInformation "Checking OS support."
		Check_OS_Name_Version="$( (. /etc/os-release; echo "${ID^^}") )-$( (. /etc/os-release; echo "${VERSION_ID}") )"
		grep -Fxq "${Check_OS_Name_Version}" <<- Check_OS_Name_Version_Supported_EOF
			SLES-12.2
			SLES_SAP-12.2
			SLES-12.3
			SLES_SAP-12.3
			SLES-12.4
			SLES_SAP-12.4
			SLES-12.5
			SLES-SAP-12.5
			SLES-15
			SLES_SAP-15
			SLES-15.1
			SLES_SAP-15.1
			SLES-15.2
			SLES_SAP-15.2
			SLES-15.3
			SLES_SAP-15.3
			RHEL-7.4
			RHEL-7.5
			RHEL-7.6
			RHEL-7.7
			RHEL-7.9
			RHEL-8.1
			RHEL-8.2
			RHEL-8.4
		Check_OS_Name_Version_Supported_EOF
		[ "${?}" -ne "0" ] && Logger.Exit Failure "Found unsupported OS_NAME_VERSION = '${Check_OS_Name_Version}'.\n${Constant_PreRequisitesMsg}"
		Logger.LogPass "Found supported OS_NAME_VERSION = '${Check_OS_Name_Version}'."
	}

	Check.Hostnames()
	{
		Logger.LogInformation "Checking HOSTNAMES."
		local hostnames="$(cat <<- HOSTNAMES_1_EOF
			$(hostname)
			$(hostname --short)
			$(hostname --fqdn)
			$(hostname --alias)
			$(ip -oneline address show | awk -F '[/ \t]+' '{print $4}')
			$(ip -resolve -oneline address show | awk -F '[/ \t]+' '{print $4}')
		HOSTNAMES_1_EOF
		)"
		hostnames="$(cat <<- HOSTNAMES_2_EOF
			${hostnames}
			$(echo "${hostnames}" | sed -r '/^([0-9\.]+)|(.*:.*)$/d' | awk -F '.' '{print $1}')
		HOSTNAMES_2_EOF
		)"
		hostnames="$(echo "${hostnames}" | sort | uniq | sed '/^[[:space:]]*$/d')"
		[ "x${hostnames}" == "x" ] && Logger.Exit Failure "Failed to determine HOSTNAMES."
		Logger.LogPass "Found HOSTNAMES = ["
		local hostname=""
		echo "${hostnames}" | while read -r hostname
		do
		{
			Logger.LogInformation "  '${hostname}'"
		}
		done
		Logger.LogPass "]"
		Check_Hostnames="${hostnames}"
	}

	Check.Waagent()
	{
		Logger.LogInformation "Restarting 'WaAgent' service."
		#systemctl restart waagent.service
		Logger.LogInformation "Checking status of 'WaAgent' service."
		systemctl is-active --quiet waagent.service
		[ "${?}" -ne "0" ] && Logger.Exit Failure "Service 'WaAgent' is not active. Please run following command to restart waagent:\n systemctl restart waagent.service\n\n"
		Logger.LogPass "Service 'WaAgent' is active."
	}

	Check.PythonXMLReq()
	{
		Logger.LogInformation "Checking python-xml package is required or not."
		local response && response=$("${Package_Python_Executable}" -c $'try:\n\timport xml.etree.ElementTree as ET\n\tprint("0")\nexcept:\n\tprint("1")')
		[ "${response}" -ne "0" ] && Package.Require PythonXML "true"
		Logger.LogPass "python-xml package dependency resolved."
	}

	Check.Wireserver()
	{
		Logger.LogInformation "Checking connectivity to 'Wireserver' service."
		local versions && versions="$(curl --silent --noproxy "*" --location --request GET "http://168.63.129.16/?comp=versions")"
		[ "${?}" -ne "0" ] && Logger.Exit Failure "Failed to connect to 'Wireserver' service."
		local version && version="$(echo "${versions}" | "${Package_Python_Executable}" -c "import xml.etree.ElementTree as ET,sys; print(ET.fromstring(sys.stdin.read()).findall('./Preferred/Version')[0].text)")"
		[ "${?}" -ne "0" ] && Logger.Exit Failure "Failed to determine WIRESERVER_VERSION."
		Logger.LogPass "Found WIRESERVER_VERSION = '${version}'."
	}

	Check.IMDS()
	{
		Logger.LogInformation "Checking connectivity to 'InstanceMetadata' service."
		local metadata && metadata="$(curl --silent --noproxy "*" --location --request GET "http://169.254.169.254/metadata/instance/compute?api-version=2019-03-11" --header "Metadata: true")"
		[ "${?}" -ne "0" ] && Logger.Exit Failure "Failed to connect to 'InstanceMetadata' service."
		Check_IMDS_VM_Region="$(echo "${metadata}" | "${Package_Python_Executable}" -c "import sys,json; print(json.load(sys.stdin)['location'].lower())" 2>/dev/null)"
		if [ "${?}" -ne "0" ]
		then
		{
			Logger.LogWarning "Failed to determine VM_REGION: Updating VM from Classic to ARM is recommended."
		}
		else
		{
			Logger.LogPass "Found VM_REGION = '${Check_IMDS_VM_Region}'."
		}
		fi
	}

	Check.HttpConnectivity()
	{
		local service="${1}"
		local verb="${2}"
		local url="${3}"
		local status="${4}"

		Logger.LogInformation "Checking connectivity to '${service}' service."
		local response && response="$(curl --silent --output /dev/null --location --request "${verb}" "${url}" --write-out "%{http_code}\n")"
		[ "${?}" -ne "0" ] && Logger.Exit Failure "Failed to connect to '${service}' service."
		[ "x${response}" != "x${status}" ] && Logger.Exit Failure "Received from '${service}' service: 'HTTP/${response}'."
		Logger.LogPass "Received from '${service}' service: 'HTTP/${response}'."
	}

	Check.TCPConnectivity()
	{
		local service="${1}"
		local url="${2}"
		local port="${3}"

		Logger.LogInformation "Checking connectivity to '${service}' service."
		local response && response=$("${Package_Python_Executable}" -c "import socket;sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM);sock.settimeout(120);print(sock.connect_ex(('${url}',${port})))")
		[ "${response}" -ne "0" ] && Logger.Exit Failure "Failed to connect to '${service}' service."
		Logger.LogPass "Connectivity check for '${service}' service successful."
	}

	Check.AadConnectivity()
	{
		Check.TCPConnectivity "AAD1" "login.windows.net" "443"
	}

	Check.ServiceConnectivity()
	{
		declare -A Check_Service_Urls=(
			[australiacentral]="https://aclpod01fab1wxsajyqyj.blob.core.windows.net,https://aclpod01fab1wxsajyqyj.queue.core.windows.net,https://pod01-prot1.acl.backup.windowsazure.com"
			[australiacentral2]="https://acl2pod01fab1wxsaa1ghw.blob.core.windows.net,https://acl2pod01fab1wxsaa1ghw.queue.core.windows.net,https://pod01-prot1.acl2.backup.windowsazure.com"
			[australiaeast]="https://aepod01fab1wxsai4sv4.blob.core.windows.net,https://aepod01fab1wxsai4sv4.queue.core.windows.net,https://pod01-prot1.ae.backup.windowsazure.com"
			[australiasoutheast]="https://asepod01fab1wxsatu7ut.blob.core.windows.net,https://asepod01fab1wxsatu7ut.queue.core.windows.net,https://pod01-prot1.ase.backup.windowsazure.com"
			[brazilsouth]="https://brspod01fab1wxsaj8cwf.blob.core.windows.net,https://brspod01fab1wxsaj8cwf.queue.core.windows.net,https://pod01-prot1.brs.backup.windowsazure.com"
			[canadacentral]="https://cncpod01fab1wxsakmklr.blob.core.windows.net,https://cncpod01fab1wxsakmklr.queue.core.windows.net,https://pod01-prot1.cnc.backup.windowsazure.com"
			[canadaeast]="https://cnepod01fab1wxsald6z1.blob.core.windows.net,https://cnepod01fab1wxsald6z1.queue.core.windows.net,https://pod01-prot1.cne.backup.windowsazure.com"
			[centralindia]="https://incpod01fab1wxsafouqx.blob.core.windows.net,https://incpod01fab1wxsafouqx.queue.core.windows.net,https://pod01-prot1.inc.backup.windowsazure.com"
			[centralus]="https://cuspod01fab1wxsar4zyr.blob.core.windows.net,https://cuspod01fab1wxsar4zyr.queue.core.windows.net,https://pod01-prot1.cus.backup.windowsazure.com"
			[chinaeast]="https://shapod01fab1wxsad4ak9.blob.core.chinacloudapi.cn,https://shapod01fab1wxsad4ak9.queue.core.chinacloudapi.cn,https://pod01-prot1.sha.backup.windowsazure.cn"
			[chinaeast2]="https://sha2pod01fab1wxsai042v.blob.core.chinacloudapi.cn,https://sha2pod01fab1wxsai042v.queue.core.chinacloudapi.cn,https://pod01-prot1.sha2.backup.windowsazure.cn"
			[chinaeast3]="https://sha3pod01fab1wxsaq50bi.blob.core.chinacloudapi.cn,https://sha3pod01fab1wxsaq50bi.queue.core.chinacloudapi.cn,https://pod01-prot1.sha3.backup.windowsazure.cn"
			[chinanorth]="https://bjbpod01fab1wxsa93erj.blob.core.chinacloudapi.cn,https://bjbpod01fab1wxsa93erj.queue.core.chinacloudapi.cn,https://pod01-prot1.bjb.backup.windowsazure.cn"
			[chinanorth2]="https://bjb2pod01fab1wxsa5pys4.blob.core.chinacloudapi.cn,https://bjb2pod01fab1wxsa5pys4.queue.core.chinacloudapi.cn,https://pod01-prot1.bjb2.backup.windowsazure.cn"
			[chinanorth3]="https://bjb3pod01fab1wxsaohap6.blob.core.chinacloudapi.cn,https://bjb3pod01fab1wxsaohap6.queue.core.chinacloudapi.cn,https://pod01-prot1.bjb3.backup.windowsazure.cn"
			[eastasia]="https://eapod01fab1wxsaa7o8l.blob.core.windows.net,https://eapod01fab1wxsaa7o8l.queue.core.windows.net,https://pod01-prot1.ea.backup.windowsazure.com"
			[eastus]="https://euspod01fab1wxsanhice.blob.core.windows.net,https://euspod01fab1wxsanhice.queue.core.windows.net,https://pod01-prot1.eus.backup.windowsazure.com"
			[eastus2]="https://eus2pod01fab1wxsadqy6r.blob.core.windows.net,https://eus2pod01fab1wxsadqy6r.queue.core.windows.net,https://pod01-prot1.eus2.backup.windowsazure.com"
			[francecentral]="https://frcpod01fab1wxsat4ryw.blob.core.windows.net,https://frcpod01fab1wxsat4ryw.queue.core.windows.net,https://pod01-prot1.frc.backup.windowsazure.com"
			[francesouth]="https://frspod01fab1wxsaxyjax.blob.core.windows.net,https://frspod01fab1wxsaxyjax.queue.core.windows.net,https://pod01-prot1.frs.backup.windowsazure.com"
			[germanycentral]="https://gecpod01fab1wxsab7hz8.blob.core.cloudapi.de,https://gecpod01fab1wxsab7hz8.queue.core.cloudapi.de,https://pod01-prot1.gec.backup.windowsazure.de"
			[germanynorth]="https://gnpod01fab1wxsa9iii0.blob.core.windows.net,https://gnpod01fab1wxsa9iii0.queue.core.windows.net,https://pod01-prot1.gn.backup.windowsazure.com"
			[germanynortheast]="https://gnepod01fab1wxsatjp3a.blob.core.cloudapi.de,https://gnepod01fab1wxsatjp3a.queue.core.cloudapi.de,https://pod01-prot1.gec.backup.windowsazure.de"
			[germanywestcentral]="https://gwcpod01fab1wxsagzbp5.blob.core.windows.net,https://gwcpod01fab1wxsagzbp5.queue.core.windows.net,https://pod01-prot1.gwc.backup.windowsazure.com"
			[japaneast]="https://jpepod01fab1wxsas2j8q.blob.core.windows.net,https://jpepod01fab1wxsas2j8q.queue.core.windows.net,https://pod01-prot1.jpe.backup.windowsazure.com"
			[japanwest]="https://jpwpod01fab1wxsaj9ksn.blob.core.windows.net,https://jpwpod01fab1wxsaj9ksn.queue.core.windows.net,https://pod01-prot1.jpw.backup.windowsazure.com"
			[koreacentral]="https://krcpod01fab1wxsa2m8aq.blob.core.windows.net,https://krcpod01fab1wxsa2m8aq.queue.core.windows.net,https://pod01-prot1.krc.backup.windowsazure.com"
			[koreasouth]="https://krspod01fab1wxsak15a6.blob.core.windows.net,https://krspod01fab1wxsak15a6.queue.core.windows.net,https://pod01-prot1.krs.backup.windowsazure.com"
			[northcentralus]="https://ncuspod01fab1wxsac19bc.blob.core.windows.net,https://ncuspod01fab1wxsac19bc.queue.core.windows.net,https://pod01-prot1.ncus.backup.windowsazure.com"
			[northeurope]="https://nepod01fab1wxsag8ksw.blob.core.windows.net,https://nepod01fab1wxsag8ksw.queue.core.windows.net,https://pod01-prot1.ne.backup.windowsazure.com"
			[qatarcentral]="https://qacpod01fab1wxsafxfxi.blob.core.windows.net,https://qacpod01fab1wxsafxfxi.queue.core.windows.net,https://pod01-prot1.qac.backup.windowsazure.com"
			[southafricanorth]="https://sanpod01fab1wxsaqslgm.blob.core.windows.net,https://sanpod01fab1wxsaqslgm.queue.core.windows.net,https://pod01-prot1.san.backup.windowsazure.com"
			[southafricawest]="https://sawpod01fab1wxsaor9bk.blob.core.windows.net,https://sawpod01fab1wxsaor9bk.queue.core.windows.net,https://pod01-prot1.saw.backup.windowsazure.com"
			[southcentralus]="https://scuspod01fab1wxsaojuir.blob.core.windows.net,https://scuspod01fab1wxsaojuir.queue.core.windows.net,https://pod01-prot1.scus.backup.windowsazure.com"
			[southeastasia]="https://seapod01fab1wxsapk732.blob.core.windows.net,https://seapod01fab1wxsapk732.queue.core.windows.net,https://pod01-prot1.sea.backup.windowsazure.com"
			[southindia]="https://inspod01fab1wxsajidjx.blob.core.windows.net,https://inspod01fab1wxsajidjx.queue.core.windows.net,https://pod01-prot1.ins.backup.windowsazure.com"
			[switzerlandnorth]="https://sznpod01fab1wxsaoh61w.blob.core.windows.net,https://sznpod01fab1wxsaoh61w.queue.core.windows.net,https://pod01-prot1.szn.backup.windowsazure.com"
			[switzerlandwest]="https://szwpod01fab1wxsazdbvl.blob.core.windows.net,https://szwpod01fab1wxsazdbvl.queue.core.windows.net,https://pod01-prot1.szw.backup.windowsazure.com"
			[uaecentral]="https://uacpod01fab1wxsa97cxf.blob.core.windows.net,https://uacpod01fab1wxsa97cxf.queue.core.windows.net,https://pod01-prot1.uac.backup.windowsazure.com"
			[uaenorth]="https://uanpod01fab1wxsaozt5l.blob.core.windows.net,https://uanpod01fab1wxsaozt5l.queue.core.windows.net,https://pod01-prot1.uan.backup.windowsazure.com"
			[uknorth]="https://uknpod01fab1wxsaf6faw.blob.core.windows.net,https://uknpod01fab1wxsaf6faw.queue.core.windows.net,https://pod01-prot1.ukn.backup.windowsazure.com"
			[uksouth]="https://ukspod01fab1wxsarr1fn.blob.core.windows.net,https://ukspod01fab1wxsarr1fn.queue.core.windows.net,https://pod01-prot1.uks.backup.windowsazure.com"
			[uksouth2]="https://uks2pod01fab1wxsaqblqp.blob.core.windows.net,https://uks2pod01fab1wxsaqblqp.queue.core.windows.net,https://pod01-prot1.uks2.backup.windowsazure.com"
			[ukwest]="https://ukwpod01fab1wxsajx51y.blob.core.windows.net,https://ukwpod01fab1wxsajx51y.queue.core.windows.net,https://pod01-prot1.ukw.backup.windowsazure.com"
			[usdodcentral]="https://udcpod01fab1wxsahrru3.blob.core.usgovcloudapi.net,https://udcpod01fab1wxsahrru3.queue.core.usgovcloudapi.net,https://pod01-prot1.udc.backup.windowsazure.us"
			[usdodeast]="https://udepod01fab1wxsaxxsyj.blob.core.usgovcloudapi.net,https://udepod01fab1wxsaxxsyj.queue.core.usgovcloudapi.net,https://pod01-prot1.ude.backup.windowsazure.us"
			[usgovarizona]="https://ugapod01fab1wxsasbss5.blob.core.usgovcloudapi.net,https://ugapod01fab1wxsasbss5.queue.core.usgovcloudapi.net,https://pod01-prot1.uga.backup.windowsazure.us"
			[usgoviowa]="https://ugipod01fab1wxsal8a5l.blob.core.usgovcloudapi.net,https://ugipod01fab1wxsal8a5l.queue.core.usgovcloudapi.net,https://pod01-prot1.ugi.backup.windowsazure.us"
			[usgovtexas]="https://ugtpod01fab1wxsayj9k8.blob.core.usgovcloudapi.net,https://ugtpod01fab1wxsayj9k8.queue.core.usgovcloudapi.net,https://pod01-prot1.ugt.backup.windowsazure.us"
			[usgovvirginia]="https://ugvpod01fab1wxsa4lrr1.blob.core.usgovcloudapi.net,https://ugvpod01fab1wxsa4lrr1.queue.core.usgovcloudapi.net,https://pod01-prot1.ugv.backup.windowsazure.us"
			[westcentralus]="https://wcuspod01fab1wxsaqdfdu.blob.core.windows.net,https://wcuspod01fab1wxsaqdfdu.queue.core.windows.net,https://pod01-prot1.wcus.backup.windowsazure.com"
			[westeurope]="https://wepod01fab1wxsa4wq1d.blob.core.windows.net,https://wepod01fab1wxsa4wq1d.queue.core.windows.net,https://pod01-prot1.we.backup.windowsazure.com"
			[westindia]="https://inwpod01fab1wxsakmfn8.blob.core.windows.net,https://inwpod01fab1wxsakmfn8.queue.core.windows.net,https://pod01-prot1.inw.backup.windowsazure.com"
			[westus]="https://wuspod01fab1wxsa95jfo.blob.core.windows.net,https://wuspod01fab1wxsa95jfo.queue.core.windows.net,https://pod01-prot1.wus.backup.windowsazure.com"
			[westus2]="https://wus2pod01fab1wxsata8kz.blob.core.windows.net,https://wus2pod01fab1wxsata8kz.queue.core.windows.net,https://pod01-prot1.wus2.backup.windowsazure.com"
			[westus3]="https://wus3pod01fab1wxsain5is.blob.core.windows.net,https://wus3pod01fab1wxsain5is.queue.core.windows.net,https://pod01-prot1.wus3.backup.windowsazure.com"
			[norwayeast]="https://nwepod01fab1wxsa56atw.blob.core.windows.net,https://nwepod01fab1wxsa56atw.queue.core.windows.net,https://pod01-prot1.nwe.backup.windowsazure.com"
			[norwaywest]="https://nwwpod01fab1wxsacnbvq.blob.core.windows.net,https://nwwpod01fab1wxsacnbvq.queue.core.windows.net,https://pod01-prot1.nww.backup.windowsazure.com"
		)

		if [ "x${Check_IMDS_VM_Region}" == "x" ]
		then
		{
			Logger.LogWarning "Skipping region specific connectivity checks on Classic VM."
		}
		else
		{
			local serviceUrls="${Check_Service_Urls["${Check_IMDS_VM_Region}"]}"
			[ "x${serviceUrls}" == "x" ] && Logger.Exit Failure "Feature not yet available in this region.\n${Constant_PreRequisitesMsg}"

			local blobUrl="$(echo "${serviceUrls}" | cut -d "," -f 1)"
			Check.HttpConnectivity "Blob" "GET" "${blobUrl}" "400"

			local queueUrl="$(echo "${serviceUrls}" | cut -d "," -f 2)"
			Check.HttpConnectivity "Queue" "GET" "${queueUrl}" "400"

			local protUrl="$(echo "${serviceUrls}" | cut -d "," -f 3)/CommonProtectionCatalogService.svc"
			Check.HttpConnectivity "Prot" "GET" "${protUrl}" "200"
		}
		fi
	}

	Check.FreeSpace()
	{
		Logger.LogInformation "Checking for free space in '${Constant_Handler_Location}'."
		local availSpaceInMB="$(df --block-size 1048576 --output=avail ${Constant_Handler_Location} | tail -n 1 | tr -d '[:space:]')"
		[ "${availSpaceInMB}" -lt "300" ] && Logger.Exit Failure "Found less than 300 MiB space on '${Constant_Handler_Location}'.\n${Constant_PreRequisitesMsg}"
		Logger.LogPass "Found at least 300 MiB space on '${Constant_Handler_Location}'."

		Logger.LogInformation "Checking for free space in '/opt'."
		local availSpaceInGB="$(df --block-size 1073741824 --output=avail /opt | tail -n 1 | tr -d '[:space:]')"
		[ "${availSpaceInGB}" -lt "2" ] && Logger.Exit Failure "Found less than 2 GiB space on '/opt'.\n${Constant_PreRequisitesMsg}"
		if [ "${availSpaceInGB}" -lt "4" ]
		then
		{
			local rootPartition="$(df / | awk '/^\/dev/ {print $1}')"
			local msawbPartition="$(df ${Constant_Msawb_Home} | awk '/^\/dev/ {print $1}')"
			[[ "$rootPartition" == "$msawbPartition" ]] && Logger.LogWarning "Note that the ${Constant_Msawb_Home} folder is in the root partition which has less than 4 GB available in size - this could lead to the root partition getting full and failing the backups.\nWe recommend you to either increase the available size of root partition to 4 GB or move the ${Constant_Msawb_Home} folder to another partition in the HANA system later."
		}
		fi
		Logger.LogPass "Found at least 2 GiB space on '/opt'."
	}
}

Plugin()
{
	{
		Plugin_Mode="add"
		Plugin_Sid=""
		Plugin_Instance_Number=""
		Plugin_User=""
		Plugin_Port_Number=""
		Plugin_Instance_Type=""
		Plugin_Instance_Version=""
		Plugin_Instance_Version_Major=""
		Plugin_Instance_Version_SPS=""
		Plugin_Driver_Path=""
		Plugin_Hdbuserstore_Path=""
		Plugin_Hdbsql_Path=""
		Plugin_Ld_Library_Path=""
		Plugin_Host_Environment_File=""
		Plugin_System_Host_Name=""
		Plugin_System_Key_Name=""
		Plugin_Backup_Key_Name=""
		Plugin_Backup_Key_User=""
		Plugin_Skip_Network_Checks="0"
		Plugin_Encrypt=""
		Plugin_Ssl_Key_Store=""
		Plugin_Ssl_Trust_Store=""
		Plugin_Ssl_Crypto_Provider=""
		Plugin_Host_Name_In_Certificate=""
		Plugin_Ssl_Validate_Certificate=""
		Plugin_Secudir=""
		Plugin_Home=""
		Plugin_HSR_Unique_Value=""
		Plugin_HSR_Primary="0"
		Plugin_IsHSRAlreadyRegistered="0"
		Plugin_AD_User="false"
	}

	Plugin.Parse()
	{
		while [ "${#}" -gt 0 ]
		do
		{
			case "${1}" in
				"-h"|"--help")
				{
					shift
					Logger.ExitOnArgumentUnexpected "${@}"
					Plugin.Help
				};;

				"-v"|"--version")
				{
					shift
					Logger.ExitOnArgumentUnexpected "${@}"
					Plugin.Version
				};;

				"-a"|"--add")
				{
					shift
					Plugin_Mode="add"
				};;

				"-r"|"--remove")
				{
					shift
					Plugin_Mode="remove"
				};;

				"-us"|"--update-script")
				{
					shift
					Plugin_Mode="update-script"
				};;

				"-s"|"--sid")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Sid="${1}"
					shift
				};;

				"-n"|"--instance-number")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Instance_Number="${1}"
					shift
				};;

				"-sk"|"--system-key")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_System_Key_Name="${1}"
					shift
				};;

				"-bk"|"--backup-key")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Backup_Key_Name="${1}"
					shift
				};;

				"-sn"|"--skip-network-checks")
				{
					shift
					Plugin_Skip_Network_Checks="1"
				};;

				"-sks"|"--sslkeystore")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Ssl_Key_Store="${1}"
					shift
				};;

				"-sts"|"--ssltruststore")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Ssl_Trust_Store="${1}"
					shift
				};;

				"-scp"|"--sslcryptoprovider")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Ssl_Crypto_Provider="${1}"
					shift
				};;

				"-sh"|"--sslhostnameincertificate")
				{
					Logger.ExitOnArgumentMissing "${@}"
					shift
					Plugin_Host_Name_In_Certificate="${1}"
					shift
				};;

				"-svc"|"--sslvalidatecertificate")
				{
					shift
					Plugin_Ssl_Validate_Certificate="true"
				};;

				"-ad" | "--ad-user")
				{
					shift
					Plugin_AD_User="true"
				};;

				*)
				{
					Logger.Exit Argument_Unknown "${1}"
				};;
			esac
		}
		done
	}

	Plugin.Run()
	{
		case "${Plugin_Mode}" in
			"add")
			{
				Plugin.Add
			};;

			"remove")
			{
				Plugin.Remove
			};;
		esac
	}

	Plugin.Add()
	{
		Package.RequireUnixODBC

		Plugin.ReadConfig

		Plugin.CheckHSRAlreadyRegistered

		if [ "x${Plugin_Config_Sid}" != "x" ]
		then
		{
			if [ "x${Plugin_Sid}" == "x" ]
			then
			{
				Logger.LogInformation "To add a different SID: Please remove the current SID with the '--remove' command."
				Plugin_Sid="${Plugin_Config_Sid}"
			}
			elif [ "x${Plugin_Sid}" != "x${Plugin_Config_Sid}" ]
			then
			{
				Logger.Exit Failure "Cannot add specified SID '${Plugin_Sid}': Please remove the current SID with the '--remove' command."
			}
			fi
		}
		fi

		[[ "${Plugin_IsHSRAlreadyRegistered}" -ne "0" && "x${Plugin_HSR_Unique_Value}" == "x" ]] && Logger.Exit Failure "This VM is registered as HSR instance. Please do stop protection for HSR instance and then run pre-registration script in standalone mode."

		if [ "x${Plugin_Sid}" == "x" ]
		then
		{
			Logger.LogInformation "Determining SID."
			Plugin_Sid="$(ls /usr/sap 2>/dev/null | grep -E '^[A-Z][0-9A-Z]{2}$' | head -n 1)"
			[ "x${Plugin_Sid}" == "x" ] && Logger.Exit Failure "Failed to determine SID: Please specify with the '--sid' option."
		}
		else
		{
			Logger.LogInformation "Using SID = '${Plugin_Sid}'."
			[ "${Plugin_Sid}" != "$(echo "${Plugin_Sid}" | grep -E '^[A-Z][0-9A-Z]{2}$')" ] && Logger.Exit Failure "Specified SID is invalid: Bad format."
			[ ! -d "/usr/sap/${Plugin_Sid}" ] && Logger.Exit Failure "Specified SID is invalid: The directory '/usr/sap/${Plugin_Sid}' does not exist."
		}
		fi
		Logger.LogPass "Found SID = '${Plugin_Sid}'."

		if [ "x${Plugin_Instance_Number}" == "x" ]
		then
		{
			Logger.LogInformation "Determining INSTANCE_NUMBER."
			Plugin_Instance_Number="$(ls /usr/sap/${Plugin_Sid} | grep -E "^HDB[0-9]{2}$" | cut -c4- | head -n 1)"
			[ "x${Plugin_Instance_Number}" == "x" ] && Logger.Exit Failure "Failed to determine INSTANCE_NUMBER: Please specify with the '--instance-number' option."
		}
		else
		{
			Logger.LogInformation "Using INSTANCE_NUMBER = '${Plugin_Instance_Number}'."
			[ "${Plugin_Instance_Number}" != "$(echo "${Plugin_Instance_Number}" | grep -E '^[0-9]{2}$')" ] && Logger.Exit Failure "Specified INSTANCE_NUMBER is invalid: Bad format."
			[ ! -d "/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}" ] && Logger.Exit Failure "Specified INSTANCE_NUMBER is invalid: The directory '/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}' does not exist."
		}
		fi
		Logger.LogPass "Found INSTANCE_NUMBER = '${Plugin_Instance_Number}'."

		Logger.LogInformation "Determining USER."
		Plugin_User="$(stat -c '%U' /usr/sap/${Plugin_Sid} 2>/dev/null)"
		[ "x${Plugin_User}" == "x" ] && Logger.Exit Failure "Failed to determine USER: Unable to read the owner of the directory '/usr/sap/${Plugin_Sid}'."
		[ "${Plugin_User}" != "${Plugin_Sid,,}adm" ] && Logger.Exit Failure "Failed to determine USER: '${Plugin_User}' does not match with the SID."
		Logger.LogPass "Found USER = '${Plugin_User}'."

		Logger.LogInformation "Determining HOSTNAME."
		Plugin.RunCommand echo "\$HOSTNAME"
		[ "x${Plugin_Run_Command_Status}" != "x0" ] && Logger.Exit Failure "Failed to determine HOSTNAME for the SAPHana Instance."
		Plugin_System_Host_Name="$(echo "${Check_Hostnames}" | while read -r checkHostname
		do [ "x${checkHostname}" == "x${Plugin_Run_Command_Output}" ] && echo "${Plugin_Run_Command_Output}" && break
		done;)"
		[ "x${Plugin_System_Host_Name}" == "x" ] && Logger.Exit Failure "Failed to determine HOSTNAME for the SAPHana Instance."
		Logger.LogPass "Found Hostname = '${Plugin_System_Host_Name}'."

		if [ "x${Plugin_HSR_Unique_Value}" == "x" ]
		then
		{
			Logger.LogInformation "Determining PORT_NUMBER."
			Plugin_Port_Number="$(awk -F '[: \t]+' '{gsub(/^[ \t]+/,"",$0)} $6=="0A" && $12=="'"$(id -u "${Plugin_User}")"'" {print $3}' /proc/net/tcp |\
			while read portNum
			do
			{
				echo "$((0x${portNum}))"
			}
			done | grep "^3${Plugin_Instance_Number}1[35]\$" | sort | head -n 1)"
			[ "x${Plugin_Port_Number}" == "x" ] && Logger.Exit Failure "Failed to determine PORT_NUMBER: Please ensure the index server is running on the SQL port."
			Logger.LogPass "Found PORT_NUMBER = '${Plugin_Port_Number}'."

			Logger.LogInformation "Determining INSTANCE_TYPE."
			[ "${Plugin_Port_Number: -2}" == "13" ] && Plugin_Instance_Type="MDC"
			[ "${Plugin_Port_Number: -2}" == "15" ] && Plugin_Instance_Type="SDC"
			[ "x${Plugin_Instance_Type}" == "x" ] && Logger.Exit Failure "Failed to determine INSTANCE_TYPE: Please ensure the index server is running on the SQL port."
			Logger.LogPass "Found INSTANCE_TYPE = '${Plugin_Instance_Type}'."

			Plugin.RunCommand "/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbnsutil" -sr_state
			local mode="$(echo "${Plugin_Run_Command_Output}" | grep -E '^mode:' | cut -d ' ' -f'2')"
			if [[ "x${mode}" == "xprimary" || "x${mode}" == "xnone" ]]; then
			{
				Plugin_HSR_Primary="1"
			}
			fi
			Logger.LogInformation "Mode is : '${mode}' and Plugin_HSR_Primary : '${Plugin_HSR_Primary}'."

		}
		else
		{

			local isProvidedHSRuniqueValueGood="false"
			[[ ${#Plugin_HSR_Unique_Value} -ge 6 && ${#Plugin_HSR_Unique_Value} -lt 35 && "$Plugin_HSR_Unique_Value" == *[A-Z]* && "$Plugin_HSR_Unique_Value" == [A-Za-z]* && "$Plugin_HSR_Unique_Value" == *[a-z]* && "$Plugin_HSR_Unique_Value" == *[0-9]* ]] && isProvidedHSRuniqueValueGood="true"
			[ "x${isProvidedHSRuniqueValueGood}" == "xfalse" ] && Logger.LogError "Please provide unique alphanumeric value for HSR instance containing atleast One upper case,one small case and one numeric digit. It should be greater or equal then 6 letter and less then 35 letter."

			Plugin.RunCommand "/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbnsutil" -sr_state
			local mode="$(echo "${Plugin_Run_Command_Output}" | grep -E '^mode:' | cut -d ' ' -f'2')"
			if [[ "x${mode}" == "xprimary" || "x${mode}" == "xnone" ]]; then
			{
				Plugin_HSR_Primary="1"
			}
			fi
			Logger.LogInformation "Mode is : '${mode}' and Plugin_HSR_Primary : '${Plugin_HSR_Primary}'."

			if [ "${Plugin_HSR_Primary}" -eq "0" ]
			then
			{
				[ "x${Plugin_Port_Number}" == "x" ] && Logger.Exit Failure "For HSR configuration for secondary system please provide the port number. Check -h option."

				Logger.LogInformation "Determining INSTANCE_TYPE."
				[ "${Plugin_Port_Number: -2}" == "13" ] && Plugin_Instance_Type="MDC"
				[ "${Plugin_Port_Number: -2}" == "15" ] && Plugin_Instance_Type="SDC"
				[ "x${Plugin_Instance_Type}" == "x" ] && Logger.Exit Failure "Failed to determine INSTANCE_TYPE: Please ensure the index server is running on the SQL port."
				Logger.LogPass "Found INSTANCE_TYPE = '${Plugin_Instance_Type}'."

			}
			else
			{
				Logger.LogInformation "Determining PORT_NUMBER."
				Plugin_Port_Number="$(awk -F '[: \t]+' '{gsub(/^[ \t]+/,"",$0)} $6=="0A" && $12=="'"$(id -u "${Plugin_User}")"'" {print $3}' /proc/net/tcp |\
				while read portNum
				do
				{
					echo "$((0x${portNum}))"
				}
				done | grep "^3${Plugin_Instance_Number}1[35]\$" | sort | head -n 1)"
				[ "x${Plugin_Port_Number}" == "x" ] && Logger.Exit Failure "Failed to determine PORT_NUMBER: Please ensure the index server is running on the SQL port."
				Logger.LogPass "Found PORT_NUMBER = '${Plugin_Port_Number}'."

				Logger.LogInformation "Determining INSTANCE_TYPE."
				[ "${Plugin_Port_Number: -2}" == "13" ] && Plugin_Instance_Type="MDC"
				[ "${Plugin_Port_Number: -2}" == "15" ] && Plugin_Instance_Type="SDC"
				[ "x${Plugin_Instance_Type}" == "x" ] && Logger.Exit Failure "Failed to determine INSTANCE_TYPE: Please ensure the index server is running on the SQL port."
				Logger.LogPass "Found INSTANCE_TYPE = '${Plugin_Instance_Type}'."
			}
			fi

		}
		fi

		Logger.LogInformation "Determining INSTANCE_VERSION."
		Plugin.RunCommand "/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/HDB" version
		Plugin_Instance_Version="$(echo "${Plugin_Run_Command_Output}" | awk '$1=="version:" {print $2}')"
		[ "x${Plugin_Instance_Version}" == "x" ] && Logger.Exit Failure "Failed to determine INSTANCE_VERSION: 'HDB' command failed."
		Logger.LogPass "Found INSTANCE_VERSION = '${Plugin_Instance_Version}'."

		Logger.LogInformation "Checking INSTANCE_VERSION support."
		Plugin_Instance_Version_Major="$(echo "${Plugin_Instance_Version}" | cut -d '.' -f 1)"
		Logger.LogInformation "Found INSTANCE_VERSION_MAJOR = '${Plugin_Instance_Version_Major}'."
		[ "${Plugin_Instance_Version_Major}" != "1" ] && [ "${Plugin_Instance_Version_Major}" != "2" ] && Logger.Exit Failure "Unsupported INSTANCE_VERSION_MAJOR.\n${Constant_PreRequisitesMsg}"
		Plugin_Instance_Version_SPS="$(expr "$(echo "${Plugin_Instance_Version}" | cut -d '.' -f 3)" / 10)"
		Logger.LogInformation "Found INSTANCE_VERSION_SPS = '${Plugin_Instance_Version_SPS}'."
		[ "${Plugin_Instance_Version_Major}" == "1" ] && [ "${Plugin_Instance_Version_SPS}" -lt 9 ] && Logger.Exit Failure "Unsupported INSTANCE_VERSION_MAJOR = '1' and INSTANCE_VERSION_SPS < '9'.\n${Constant_PreRequisitesMsg}"
		[ "${Plugin_Instance_Version_Major}" == "2" ] && [ "${Plugin_Instance_Version_SPS}" -gt 6 ] && Logger.Exit Failure "Unsupported INSTANCE_VERSION_MAJOR = '2' and INSTANCE_VERSION_SPS > '6'.\n${Constant_PreRequisitesMsg}"
		Logger.LogPass "Supported INSTANCE_VERSION."

		Logger.LogInformation "Determining DRIVER_PATH."
		Plugin_Ld_Library_Path="/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe"
		[ ! -d ${Plugin_Ld_Library_Path} ] && Logger.Exit Failure "Failed to determine DRIVER_PATH: Please ensure instance 'exe' directory '/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe' exists."
		Plugin_Driver_Path="$(ls /usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/libodbcHDB.so 2>/dev/null)"
		[ "x${Plugin_Driver_Path}" == "x" ] && Logger.Exit Failure "Failed to determine DRIVER_PATH: Please ensure 'libodbcHDB.so' is correctly installed in the instance 'exe' directory."
		Plugin_Hdbuserstore_Path="$(ls /usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbuserstore 2>/dev/null)"
		[ "x${Plugin_Hdbuserstore_Path}" == "x" ] && Logger.Exit Failure "Failed to determine DRIVER_PATH: Please ensure 'hdbuserstore' is correctly installed in the instance 'exe' directory."
		Plugin_Hdbsql_Path="$(ls /usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbsql 2>/dev/null)"
		[ "x${Plugin_Hdbsql_Path}" == "x" ] && Logger.Exit Failure "Failed to determine DRIVER_PATH: Please ensure 'hdbsql' is correctly installed in the instance 'exe' directory."
		Logger.LogPass "Found DRIVER_PATH = '${Plugin_Driver_Path}'."

		if [ "x${Plugin_System_Key_Name}" == "x" ]
		then
		{
			Logger.LogInformation "Determining SYSTEM_KEY_NAME."
			Plugin.FindKeyByUser "SYSTEM"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogWarning "Failed to determine SYSTEM_KEY_NAME: Please specify with the '--system-key' option.\n${Constant_UserHints_SystemKeyCreationMsg}"
			}
			else
			{
				Logger.LogPass "Found SYSTEM_KEY_NAME = '${Plugin_Find_Key_Name}'."
				Plugin_System_Key_Name="${Plugin_Find_Key_Name}"
			}
			fi
		}
		else
		{
			Logger.LogInformation "Using SYSTEM_KEY_NAME = '${Plugin_System_Key_Name}'."
			Plugin.FindKeyByName "${Plugin_System_Key_Name}"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogWarning "Specified SYSTEM_KEY_NAME is invalid: Please ensure that it is available in the hdbuserstore.\n${Constant_UserHints_SystemKeyCreationMsg}"
				Plugin_System_Key_Name=""
			}
			else
			{
				Logger.LogPass "Found SYSTEM_KEY_NAME = '${Plugin_Find_Key_Name}'."
			}
			fi
		}
		fi

		if [ "x${Plugin_Backup_Key_Name}" == "x" ]
		then
		{

			Logger.LogInformation "Checking HSR unique value."
			if [ "x${Plugin_HSR_Unique_Value}" == "x" ]
			then
			{
				Logger.LogInformation "Pre-reg script is run for standalone system. Continuing..."
			}
			else
			{
				Logger.Exit Failure "HSR Configuration requires custom backup key, please re-run with custom backup key."
			}
			fi

			Logger.LogInformation "Determining BACKUP_KEY_NAME."
			Plugin.FindKeyByUser "${Constant_Plugin_Default_Backup_Key_User}" "$(hostname)"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogInformation "Failed to determine BACKUP_KEY_NAME: Will create one in the hdbuserstore."
				Plugin_Backup_Key_Name="${Constant_Plugin_Default_Backup_Key_Name}"
				Plugin_Backup_Key_User="${Constant_Plugin_Default_Backup_Key_User}"
				Plugin_Backup_Key_Exists=0
			}
			else
			{
				Logger.LogPass "Found BACKUP_KEY_NAME = '${Plugin_Find_Key_Name}': Will check and repair as needed."
				Plugin_Backup_Key_Name="${Plugin_Find_Key_Name}"
				Plugin_Backup_Key_User="${Plugin_Find_Key_User}"
				Plugin_Backup_Key_Exists=1
			}
			fi
		}
		else
		{
			Logger.LogInformation "Using BACKUP_KEY_NAME = '${Plugin_Backup_Key_Name}'."
			Plugin.FindKeyByName "${Plugin_Backup_Key_Name}" "$(hostname)"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogWarning "Specified BACKUP_KEY_NAME is invalid: Will create one in the hdbuserstore."
				Plugin_Backup_Key_User="${Constant_Plugin_Default_Backup_Key_User}"
				Plugin_Backup_Key_Exists=0
			}
			else
			{
				Logger.LogPass "Found BACKUP_KEY_NAME = '${Plugin_Find_Key_Name}': Will check and repair as needed."
				Plugin_Backup_Key_User="${Plugin_Find_Key_User}"
				Plugin_Backup_Key_Exists=1
			}
			fi
		}
		fi

		Plugin.SslConfig

		if [ "${Plugin_Backup_Key_Exists}" -eq "1" ]
		then
		{
			if [[ "${Plugin_HSR_Primary}" -eq "1" || "x${Plugin_HSR_Unique_Value}" == "x" ]]
			then
			{
				Plugin.LoginUser
				Plugin_Backup_Key_Exists="${Plugin_Login_User_Result}"
			}
			else
			{
				Logger.LogWarning "Skipping user checking for secondary node in HSR configuration."
			}
			fi
		}
		fi

		if [ "${Plugin_Backup_Key_Exists}" -ne "1" ]
		then
		{
			[ "${Plugin_Backup_Key_User}" != "${Constant_Plugin_Default_Backup_Key_User}" ] && Logger.Exit Failure "Will not modify non-standard backup user '${Plugin_Find_Key_User}'."
			[ "x${Plugin_System_Key_Name}" == "x" ] && Logger.Exit Failure "Need a valid system key to create the backup key.\n${Constant_UserHints_SystemKeyCreationMsg}"
			Plugin.CheckSystemOverview
			Plugin.DeleteUser
			Plugin.CreateUser
			Plugin.AlterUser
			Plugin.LoginUser
			Plugin_Backup_Key_Exists="${Plugin_Login_User_Result}"
			[ "${Plugin_Backup_Key_Exists}" -ne "1" ] && Logger.Exit Failure "Failed to create and login with backup user."
		}
		else
		{
			if [[ "${Plugin_HSR_Primary}" -eq "1" || "x${Plugin_HSR_Unique_Value}" == "x" ]]
			then
			{
				Plugin.CheckSystemOverview
				Plugin.CheckUser
			}
			else
			{
				Logger.LogWarning "Skipping user and system overview checking for secondary node in HSR configuration."
			}
			fi

		}
		fi

		if [[ "${Plugin_Check_User_Result}" != "1" && "${Plugin_HSR_Primary}" -eq "1" ]]
		then
		{
			[ "x${Plugin_System_Key_Name}" == "x" ] && Logger.Exit Failure "Need a valid system key to repair the backup key.\n${Constant_UserHints_SystemKeyCreationMsg}"
			Plugin.GrantUser
			Plugin.CheckUser
			[ "${Plugin_Check_User_Result}" != "1" ] && Logger.Exit Failure "Failed to grant backup privileges to backup user."
		}
		else
		{
			[[ "${Plugin_HSR_Primary}" -eq "0" && "x${Plugin_HSR_Unique_Value}" != "x" ]] && Logger.LogWarning "Skipping grant and user checking for secondary node in HSR configuration."
		}
		fi

		# TODO: Remove use of isADUser key in config 
		if [ "x${Plugin_AD_User}" == "xfalse" ]
		then
		{
			Plugin.AddSupplementaryGroupToUser
		}
		else
		{
			Logger.LogWarning "Skipping adding '${Plugin_User}' user to local '${Constant_Msawb_Group_Secondary}' group."
			Plugin.CheckIfUserIsAddedToGroup
		}
		fi

		Plugin.WriteConfig
		Plugin.WriteEnvironment
	}

	# TODO: Check if this will work when system is protected as standalone and then stop protected later
	Plugin.CheckHSRAlreadyRegistered()
	{
		if [ -d "/opt/msawb/var/lib/catalog/RegisteredObjectInfoCatalog/RegisteredObjectInfoTable/" ]; then
			local result && result="$(find /opt/msawb/var/lib/catalog/RegisteredObjectInfoCatalog/RegisteredObjectInfoTable/ -type f -name '*.bin' -exec grep -i '\"ObjectType\": 2' {} \; | wc -l)"
			[ "${?}" -eq "0" ] && Plugin_IsHSRAlreadyRegistered=${result}
			[ "${Plugin_IsHSRAlreadyRegistered}" -eq "0" ] && Logger.LogInformation "HSR instance not registered on this VM."
			[ "${Plugin_IsHSRAlreadyRegistered}" -ne "0" ] && Logger.LogInformation "HSR instance registered on this VM."
		fi
	}

	Plugin.SslConfig()
	{
		Logger.LogInformation "Determining SSL configuration."
		
		hostname=$(hostname)
		sslEnforce=""

		SAP_HANA_SYSTEM_CONFIG="/usr/sap/${Plugin_Sid}/SYS/global/hdb/custom/config/global.ini"
		SAP_HANA_DEFAULT_CONFIG="/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/config/global.ini"
		SAP_HANA_HOST_CONFIG="/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/${hostname,,}/global.ini"
		SAP_HANA_DATABASE_CONFIG="${SAP_HANA_SYSTEM_CONFIG}"

		if [ -f "$SAP_HANA_SYSTEM_CONFIG" ]; then
			sslEnforce=$(sed -nr "{ :l /^ssl[Ee]nforce[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_SYSTEM_CONFIG}") 
		fi
		

		if [ "${sslEnforce}" == "true" ];
		then
		{
			Plugin_Secudir="/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/${hostname,,}/sec"
			Plugin.RunCommand echo "\$HOME"
			[ "x${Plugin_Run_Command_Status}" != "x0" ] && Logger.Exit Failure "Failed to determine HOME variable for '${Plugin_User}'."
			Plugin_Home="${Plugin_Run_Command_Output}"

			Plugin_Encrypt="true"
			
			if [ "x${Plugin_Ssl_Key_Store}" == "x" ];
			then 
			{
				if [ -f "$SAP_HANA_HOST_CONFIG" ]; then
					Plugin_Ssl_Key_Store=$(sed -nr "{ :l /^ssl[Kk]ey[Ss]tore[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_HOST_CONFIG}")
				fi
				
				if [ "x${Plugin_Ssl_Key_Store}" == "x" ]; then
					Plugin_Ssl_Key_Store=$(sed -nr "{ :l /^ssl[Kk]ey[Ss]tore[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_DEFAULT_CONFIG}")
				fi
			}
			fi
			

			if [ "x${Plugin_Ssl_Trust_Store}" == "x" ];
			then 
			{
				if [ -f "$SAP_HANA_HOST_CONFIG" ]; then
					Plugin_Ssl_Trust_Store=$(sed -nr "{ :l /^ssl[Tt]rust[Ss]tore[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_HOST_CONFIG}")
				fi
				
				if [ "x${Plugin_Ssl_Trust_Store}" == "x" ]; then
					Plugin_Ssl_Trust_Store=$(sed -nr "{ :l /^ssl[Tt]rust[Ss]tore[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_DEFAULT_CONFIG}")
				fi
			}
			fi

			if [ "x${Plugin_Ssl_Crypto_Provider}" == "x" ];
			then 
			{
				if [ -f "$SAP_HANA_HOST_CONFIG" ]; then
					Plugin_Ssl_Crypto_Provider=$(sed -nr "{ :l /^ssl[Cc]rypto[Pp]rovider[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_HOST_CONFIG}")
				fi
				
				if [ "x${Plugin_Ssl_Crypto_Provider}" == "x" ]; then
					Plugin_Ssl_Crypto_Provider=$(sed -nr "{ :l /^ssl[Cc]rypto[Pp]rovider[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_DEFAULT_CONFIG}")
				fi
			}
			fi

			Logger.LogPass "Found SslCryptoProvider = ${Plugin_Ssl_Crypto_Provider}"

			if [ "x${Plugin_Ssl_Validate_Certificate}" == "x" ];
			then 
			{
				if [ -f "$SAP_HANA_HOST_CONFIG" ]; then
					Plugin_Ssl_Validate_Certificate=$(sed -nr "{ :l /^ssl[Vv]alidate[Cc]ertificate[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_HOST_CONFIG}")
				fi
				
				if [ "x${Plugin_Ssl_Crypto_Provider}" == "x" ]; then
					Plugin_Ssl_Validate_Certificate=$(sed -nr "{ :l /^ssl[Vv]alidate[Cc]ertificate[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "${SAP_HANA_DEFAULT_CONFIG}")
				fi
			}
			fi

			Logger.LogPass "SslValidateCertificate is set to = ${Plugin_Ssl_Validate_Certificate}"

			if [ "${Plugin_Ssl_Crypto_Provider}" == "commoncrypto" ]; 
			then 
			{	
				[ ! -f "$Plugin_Ssl_Key_Store" ] && Plugin_Ssl_Key_Store="${Plugin_Secudir}/${Plugin_Ssl_Key_Store}"
				[ -f "$Plugin_Ssl_Key_Store" ] && Logger.LogPass "Found SslKeyStore = ${Plugin_Ssl_Key_Store}" || Logger.Exit Failure "SslKeyStore - ${Plugin_Ssl_Key_Store} does not exist. Please specify SslKeyStore file with -sks parameter. Refer to --help for more information."
				[ ! -f "$Plugin_Ssl_Trust_Store" ] && Plugin_Ssl_Trust_Store="${Plugin_Secudir}/${Plugin_Ssl_Trust_Store}"
				[ -f "$Plugin_Ssl_Trust_Store" ] && Logger.LogPass "Found SslTrustStore = ${Plugin_Ssl_Trust_Store}" || Logger.Exit Failure "SslTrustStore - ${Plugin_Ssl_Trust_Store} does not exist. Please specify SslTrustStore file with -sts parameter. Refer to --help for more information."
			
			} elif [ "${Plugin_Ssl_Crypto_Provider}" == "openssl" ];
			then
			{
				[ ! -f "$Plugin_Ssl_Key_Store" ] && Plugin_Ssl_Key_Store="${Plugin_Home}/.ssl/${Plugin_Ssl_Key_Store}"
				[ -f "$Plugin_Ssl_Key_Store" ] && Logger.LogPass "Found SslKeyStore = ${Plugin_Ssl_Key_Store}" || Logger.Exit Failure "SslKeyStore - ${Plugin_Ssl_Key_Store} does not exist. Please specify SslKeyStore file with -sks parameter. Refer to --help for more information."
				[ ! -f "$Plugin_Ssl_Trust_Store" ] && Plugin_Ssl_Trust_Store="${Plugin_Home}/.ssl/${Plugin_Ssl_Trust_Store}"
				[ -f "$Plugin_Ssl_Trust_Store" ] && Logger.LogPass "Found SslTrustStore = ${Plugin_Ssl_Trust_Store}" || Logger.Exit Failure "SslTrustStore - ${Plugin_Ssl_Trust_Store} does not exist. Please specify SslTrustStore file with -sts parameter. Refer to --help for more information."
			}
			fi
		
			if [ "x${Plugin_Host_Name_In_Certificate}" == "x" ];
			then
			{
				if [ "${Plugin_Ssl_Crypto_Provider}" == "commoncrypto" ]; 
				then
				{
					Plugin.RunCommand sapgenpse get_my_name -p "${Plugin_Ssl_Key_Store}" -n Subject 2>&1
					Plugin_Host_Name_In_Certificate="$(echo "${Plugin_Run_Command_Output}" | grep -E CN= | cut -d '=' -f2 | cut -d ',' -f1)"
				} 
				elif [ "${Plugin_Ssl_Crypto_Provider}" == "openssl" ];
				then 
				{
					Plugin.RunCommand openssl x509 -noout -subject -in "${Plugin_Ssl_Trust_Store}" 
					Plugin_Host_Name_In_Certificate="$(echo "${Plugin_Run_Command_Output}" | sed -e 's/^subject.*CN=\([a-zA-Z0-9\.\-]*\).*$/\1/')"
				}
				fi
			}
			fi

			[ "x${Plugin_Host_Name_In_Certificate}" != "x" ] && Logger.LogPass "Found SslHostnameInCertificate = ${Plugin_Host_Name_In_Certificate}" || Logger.Exit Failure "No value for SslHostNameInCertificate found. Please specify SslHostNameInCertificate with -sh parameter. Refer to --help for more information."
		
			Logger.LogInformation "SSL is configured."
		}
		else
		{
			Logger.LogInformation "SSL is not configured."
		}
		fi
	}

	Plugin.Remove()
	{
		Plugin.ReadConfig

		[ "x${Plugin_Config_Sid}" == "x" ] && Logger.Exit Failure "No SID to remove found in configuration."
		[ "x${Plugin_Sid}" == "x" ] && Logger.Exit Failure "The '--sid' option is mandatory for the '--remove' command."
		[ "${Plugin_Config_Sid}" != "${Plugin_Sid}" ] && Logger.Exit Failure "The specified SID is not present in the configuration."

		if [ "x${Plugin_Instance_Number}" == "x" ]
		then
		{
			Logger.LogInformation "Determining INSTANCE_NUMBER."
			Plugin_Instance_Number="$(ls /usr/sap/${Plugin_Sid} | grep -E "^HDB[0-9]{2}$" | cut -c4- | head -n 1)"
			[ "x${Plugin_Instance_Number}" == "x" ] && Logger.Exit Failure "Failed to determine INSTANCE_NUMBER: Please specify with the '--instance-number' option."
		}
		else
		{
			Logger.LogInformation "Using INSTANCE_NUMBER = '${Plugin_Instance_Number}'."
			[ "${Plugin_Instance_Number}" != "$(echo "${Plugin_Instance_Number}" | grep -E '^[0-9]{2}$')" ] && Logger.Exit Failure "Specified INSTANCE_NUMBER is invalid: Bad format."
			[ ! -d "/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}" ] && Logger.Exit Failure "Specified INSTANCE_NUMBER is invalid: The directory '/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}' does not exist."
		}
		fi
		Logger.LogPass "Found INSTANCE_NUMBER = '${Plugin_Instance_Number}'."

		Logger.LogInformation "Determining USER."
		Plugin_User="$(stat -c '%U' /usr/sap/${Plugin_Sid} 2>/dev/null)"
		[ "x${Plugin_User}" == "x" ] && Logger.Exit Failure "Failed to determine USER: Unable to read the owner of the directory '/usr/sap/${Plugin_Sid}'."
		[ "${Plugin_User}" != "${Plugin_Sid,,}adm" ] && Logger.Exit Failure "Failed to determine USER: '${Plugin_User}' does not match with the SID."
		Logger.LogPass "Found USER = '${Plugin_User}'."

		if [ "x${Plugin_HSR_Unique_Value}" == "x" ]
		then
		{
			Logger.LogInformation "Determining PORT_NUMBER."
			Plugin_Port_Number="$(awk -F '[: \t]+' '{gsub(/^[ \t]+/,"",$0)} $6=="0A" && $12=="'"$(id -u "${Plugin_User}")"'" {print $3}' /proc/net/tcp |\
			while read portNum
			do
			{
				echo "$((0x${portNum}))"
			}
			done | grep "^3${Plugin_Instance_Number}1[35]\$" | sort | head -n 1)"
			[ "x${Plugin_Port_Number}" == "x" ] && Logger.Exit Failure "Failed to determine PORT_NUMBER: Please ensure the index server is running on the SQL port."
			Logger.LogPass "Found PORT_NUMBER = '${Plugin_Port_Number}'."
		}
		else
		{
			local isProvidedHSRuniqueValueGood="false"
			[[ ${#Plugin_HSR_Unique_Value} -ge 6 && ${#Plugin_HSR_Unique_Value} -lt 35 && "$Plugin_HSR_Unique_Value" == *[A-Z]* && "$Plugin_HSR_Unique_Value" == [A-Za-z]* && "$Plugin_HSR_Unique_Value" == *[a-z]* && "$Plugin_HSR_Unique_Value" == *[0-9]* ]] && isProvidedHSRuniqueValueGood="true"
			[ "x${isProvidedHSRuniqueValueGood}" == "xfalse" ] && Logger.LogError "Please provide unique alphanumeric value for HSR instance containing atleast One upper case,one small case and one numeric digit. It should be greater or equal then 6 letter and less then 35 letter."

			Plugin.RunCommand "/usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbnsutil" -sr_state
			local mode="$(echo "${Plugin_Run_Command_Output}" | grep -E '^mode:' | cut -d ' ' -f'2')"
			if [[ "x${mode}" == "xprimary" || "x${mode}" == "xnone" ]]; then
			{
				Plugin_HSR_Primary="1"
			}
			fi
			Logger.LogInformation "Mode is : '${mode}' and Plugin_HSR_Primary : '${Plugin_HSR_Primary}'."

			if [ "${Plugin_HSR_Primary}" -eq "0" ]
			then
			{
				[ "x${Plugin_Port_Number}" == "x" ] && Logger.Exit Failure "For HSR configuration for secondary system please provide the port number. Check -h option."
			}
			else
			{
				Logger.LogInformation "Determining PORT_NUMBER."
				Plugin_Port_Number="$(awk -F '[: \t]+' '{gsub(/^[ \t]+/,"",$0)} $6=="0A" && $12=="'"$(id -u "${Plugin_User}")"'" {print $3}' /proc/net/tcp |\
				while read portNum
				do
				{
					echo "$((0x${portNum}))"
				}
				done | grep "^3${Plugin_Instance_Number}1[35]\$" | sort | head -n 1)"
				[ "x${Plugin_Port_Number}" == "x" ] && Logger.Exit Failure "Failed to determine PORT_NUMBER: Please ensure the index server is running on the SQL port."
				Logger.LogPass "Found PORT_NUMBER = '${Plugin_Port_Number}'."
			}
			fi
		}
		fi

		Logger.LogInformation "Determining HDBUSERSTORE_PATH."
		Plugin_Hdbuserstore_Path="$(ls /usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbuserstore 2>/dev/null)"
		[ "x${Plugin_Hdbuserstore_Path}" == "x" ] && Logger.Exit Failure "Failed to determine HDBUSERSTORE_PATH: Please ensure 'hdbuserstore' is correctly installed in the instance 'exe' directory."
		Logger.LogPass "Found HDBUSERSTORE_PATH = '${Plugin_Hdbuserstore_Path}'."
		Logger.LogInformation "Determining HDBSQL_PATH."
		Plugin_Hdbsql_Path="$(ls /usr/sap/${Plugin_Sid}/HDB${Plugin_Instance_Number}/exe/hdbsql 2>/dev/null)"
		[ "x${Plugin_Hdbsql_Path}" == "x" ] && Logger.Exit Failure "Failed to determine HDBSQL_PATH: Please ensure 'hdbsql' is correctly installed in the instance 'exe' directory."
		Logger.LogPass "Found HDBSQL_PATH = '${Plugin_Hdbsql_Path}'."

		if [ "x${Plugin_System_Key_Name}" == "x" ]
		then
		{
			Logger.LogInformation "Determining SYSTEM_KEY_NAME."
			Plugin.FindKeyByUser "SYSTEM"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogWarning "Failed to determine SYSTEM_KEY_NAME: Please specify with the '--system-key' option.\n${Constant_UserHints_SystemKeyCreationMsg}"
			}
			else
			{
				Logger.LogPass "Found SYSTEM_KEY_NAME = '${Plugin_Find_Key_Name}'."
				Plugin_System_Key_Name="${Plugin_Find_Key_Name}"
			}
			fi
		}
		else
		{
			Logger.LogInformation "Using SYSTEM_KEY_NAME = '${Plugin_System_Key_Name}'."
			Plugin.FindKeyByName "${Plugin_System_Key_Name}"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogWarning "Specified SYSTEM_KEY_NAME is invalid: Please ensure that it is available in the hdbuserstore.\n${Constant_UserHints_SystemKeyCreationMsg}"
				Plugin_System_Key_Name=""
			}
			else
			{
				Logger.LogPass "Found SYSTEM_KEY_NAME = '${Plugin_Find_Key_Name}'."
			}
			fi
		}
		fi

		Logger.LogInformation "Checking if SID is registered."
		Plugin_Host_Service_File="${Constant_Plugin_Host_Service_File_Old//\{1\}/${Plugin_Sid,,}}"
		[ -f "${Plugin_Host_Service_File}" ] && Logger.Exit Failure "SID is still registered. Please un-register it first."
		Logger.LogPass "SID is un-registered."

		if [ "x${Plugin_Config_Backup_Key_Name}" != "x" ]
		then
		{
			Logger.LogInformation "Determining BACKUP_KEY_NAME and BACKUP_KEY_USER."
			Plugin.FindKeyByUser "${Constant_Plugin_Default_Backup_Key_User}" "$(hostname)"

			if [ "x${Plugin_Find_Key_Name}" == "x" ]
			then
			{
				Logger.LogWarning "Failed to determine BACKUP_KEY_NAME from hdbuserstore. Skipping removal of BACKUP_KEY_NAME and BACKUP_KEY_USER."
				Plugin_Backup_Key_Exists=0
			}
			else
			{
				Logger.LogPass "Found BACKUP_KEY_NAME = '${Plugin_Find_Key_Name}': Will remove key."
				Logger.LogPass "Found BACKUP_KEY_USER = '${Plugin_Find_Key_User}': Will remove user."
				Plugin_Backup_Key_Name="${Plugin_Find_Key_Name}"
				Plugin_Backup_Key_User="${Plugin_Find_Key_User}"
				Plugin_Backup_Key_Exists=1

				[ "x${Plugin_Config_Backup_Key_Name}" != "x${Plugin_Backup_Key_Name}" ] && Logger.Exit Failure "BACKUP_KEY_NAME found in configuration and in hdbuserstore do not match."
			}
			fi
		}
		else
		{
			Logger.Exit Failure "No BACKUP_KEY_NAME found in configuration."
			Plugin_Backup_Key_Exists=0
		}
		fi

		[ "${Plugin_Backup_Key_Exists}" -eq "1" ] && Plugin.DeleteUser
		[ "x${Plugin_Config_AD_User}" == "xfalse" ] && Plugin.RemoveSupplementaryGroupFromUser
		Plugin.WriteConfig
		Plugin.WriteEnvironment
	}

	Plugin.ReadInstanceKeys()
	{
		local keyName="${1}"
		local hostName="${2}"
		local hdbuserstoreArgs=()
		if [ "x${hostName}" != "x" ]
		then
		{
			hdbuserstoreArgs+=("unset" "HDB_USE_IDENT" "&&" "${Plugin_Hdbuserstore_Path}" "-H" "${hostName}" "LIST")
		}
		else
		{
			hdbuserstoreArgs+=("${Plugin_Hdbuserstore_Path}" "LIST")
		}
		fi
		[ "x${keyName}" != "x" ] && hdbuserstoreArgs+=("${keyName}")
		Plugin.RunCommand "${hdbuserstoreArgs[@]}"
		local hdbHostKeys="$(echo "${Plugin_Run_Command_Output}"  | sed -r '/^(.*\/.*)?$/d' | sed -r 's/^\s+([A-Z]+)\s*:\s+(.+)$/\1="\2"/' | sed -r 's/^KEY\s+(.+)$/;KEY="\1"/' | tr -s ';\n' '\n ' | sed '/^[[:space:]]*$/d')"
		Plugin_Read_Instance_Keys="$(echo "${hdbHostKeys}" | while read -r hdbHostKey
		do echo "${hdbHostKey}" | sed -r 's/^.*ENV="([^"]+)".*$/\1/' | tr "," "\n" | while read -r hdbHostEnv
		do echo "${Check_Hostnames}" | while read -r checkHostname
		do [ "x${checkHostname}:${Plugin_Port_Number}" == "x${hdbHostEnv}" ] && echo "${hdbHostKey}" && break
		done; done; done | sort | uniq)"
	}

	Plugin.FindKeyByName()
	{
		local keyName="${1}"
		local hostName="${2}"
		Plugin_Find_Key_Name=""
		Plugin_Find_Key_User=""
		Plugin.ReadInstanceKeys "${keyName}" "${hostName}"
		local hdbUserKeys="$(echo "${Plugin_Read_Instance_Keys}" | grep -F "KEY=\"${keyName}\"")"
		[ "x${hdbUserKeys}" != "x" ] && Plugin_Find_Key_Name="${keyName}" && Plugin_Find_Key_User="$(echo "${hdbUserKeys}" | head -n 1 | sed -r 's/^.*USER="([^"]+)".*$/\1/')"
	}

	Plugin.FindKeyByUser()
	{
		local userName="${1}"
		local hostName="${2}"
		Plugin_Find_Key_Name=""
		Plugin_Find_Key_User=""
		Plugin.ReadInstanceKeys "" "${hostName}"
		local hdbUserKeys="$(echo "${Plugin_Read_Instance_Keys}" | grep -F "USER=\"${userName}\"")"
		[ "x${hdbUserKeys}" != "x" ] && Plugin_Find_Key_Name="$(echo "${hdbUserKeys}" | head -n 1 | sed -r 's/^.*KEY="([^"]+)".*$/\1/')" && Plugin_Find_Key_User="${userName}"
	}

	Plugin.RunCommand()
	{
		local escapedCommand=""
		while [ "${#}" -gt 0 ]
		do
		{
			case "${1}" in
				"&&"|"||")
				{
					escapedCommand="${escapedCommand}${1} "
				};;
				*)
				{
					escapedCommand="${escapedCommand}\"${1//\"/\\\"}\" "
				};;
			esac
			shift
		}
		done
		Plugin_Run_Command_Output="$(runuser --login "${Plugin_User}" --shell ${SHELL} 3>&1 1>/dev/null 2>/dev/null <<- Plugin_Run_Command_EOF
			exec 1>&3 2>&3
			${escapedCommand}
			Plugin_Run_Command_EOF
		)"
		Plugin_Run_Command_Status="${?}"
	}

	Plugin.RunQuery()
	{
		local keyName="${1}"
		local query="${2}"
		local hostName="${3}"
		local hdbsqlArgs=()
		[ "x${hostName}" != "x" ] && hdbsqlArgs+=("export" "HDB_USE_IDENT=\"${hostName}\"" "&&")
		hdbsqlArgs+=("${Plugin_Hdbsql_Path}" -i "${Plugin_Instance_Number}" -n "localhost:${Plugin_Port_Number}")
		[ "${Plugin_Instance_Type}" == "MDC" ] && hdbsqlArgs+=(-d SYSTEMDB)
		if [ "${Plugin_Encrypt}" == "true" ];
		then
		{
			hdbsqlArgs+=(-e -sslkeystore "${Plugin_Ssl_Key_Store}" -ssltruststore "${Plugin_Ssl_Trust_Store}" -sslhostnameincert "${Plugin_Host_Name_In_Certificate}" -sslprovider "${Plugin_Ssl_Crypto_Provider}")
		}
		fi
		hdbsqlArgs+=(-U "${keyName}" -xCja "${query}")
		Plugin.RunCommand "${hdbsqlArgs[@]}"
		Plugin_Run_Query_Output="${Plugin_Run_Command_Output}"
		Plugin_Run_Query_Status="${Plugin_Run_Command_Status}"
		[ "x${Plugin_Run_Query_Status}" != "x0" ] && Logger.LogWarning "Failed (${Plugin_Run_Query_Status}) to run QUERY: '${Plugin_Run_Query_Output}'."
	}

	Plugin.RunQueryAsSystem()
	{
		Plugin.RunQuery "${Plugin_System_Key_Name}" "${1}"
	}

	Plugin.RunQueryAsBackup()
	{
		Plugin.RunQuery "${Plugin_Backup_Key_Name}" "${1}" "$(hostname)"
	}

	Plugin.CheckSystemOverview()
	{
		Logger.LogInformation "Connecting to the instance and checking system overview."

		local query="SELECT SECTION, NAME, STATUS, VALUE FROM SYS.M_SYSTEM_OVERVIEW"
		if [ "${Plugin_Backup_Key_Exists}" -eq "1" ]
		then
		{
			Plugin.RunQueryAsBackup "${query}"
		}
		else
		{
			Plugin.RunQueryAsSystem "${query}"
		}
		fi
		local systemOverview="${Plugin_Run_Query_Output}"

		local systemOverviewSid="$(echo "${systemOverview}" | awk -F ',' '$1=="System" && $2=="Instance ID" {print $4}')"
		[ "x${systemOverviewSid}" != "x${Plugin_Sid}" ] && Logger.Exit Failure "Mismatched SID = '${systemOverviewSid}'."
		Logger.LogInformation "Found SID = '${systemOverviewSid}'."

		local systemOverviewNum="$(echo "${systemOverview}" | awk -F ',' '$1=="System" && $2=="Instance Number" {print $4}')"
		[ "x${systemOverviewNum}" != "x${Plugin_Instance_Number}" ] && Logger.Exit Failure "Mismatched INSTANCE_NUMBER = '${systemOverviewNum}'."
		Logger.LogInformation "Found INSTANCE_NUMBER = '${systemOverviewNum}'."

		local systemOverviewDistributed="$(echo "${systemOverview}" | awk -F ',' '$1=="System" && $2=="Distributed" {print $4}')"
		[ "x${systemOverviewDistributed}" != "xNo" ] && Logger.Exit Failure "Unsupported INSTANCE_MODE = 'Distributed'."
		Logger.LogInformation "Found INSTANCE_MODE = 'Standalone'."

		local systemOverviewStatus="$(echo "${systemOverview}" | awk -F ',' '$1=="Services" && $2=="All Started" {print $4}')"
		[ "x${systemOverviewStatus}" != "xYes" ] && Logger.Exit Failure "Unhealthy instance with SERVICES_ALL_STARTED = 'No'."
		Logger.LogInformation "Found SERVICES_ALL_STARTED = 'Yes'."

		Logger.LogPass "System overview checks succeeded."
	}

	Plugin.DeleteUser()
	{
		Logger.LogInformation "Deleting BACKUP_KEY_USER = '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsSystem "DROP USER ${Plugin_Backup_Key_User} CASCADE"
		local deleteResult="${Plugin_Run_Query_Output}"
		[ "x${deleteResult}" != "x" ] && [ "x$(echo "${deleteResult}" | grep -F ' 332: ')" == "x" ] && Logger.Exit Failure "Failed to delete BACKUP_KEY_USER: '${deleteResult}'."
		if [ "x${deleteResult}" != "x" ]
		then
		{
			Logger.LogPass "The BACKUP_KEY_USER does not exist."
		}
		else
		{
			Logger.LogPass "Deleted BACKUP_KEY_USER."
		}
		fi
		Logger.LogInformation "Deleting BACKUP_KEY_NAME = '${Plugin_Backup_Key_Name}'."
		Plugin.RunCommand unset HDB_USE_IDENT "&&" "${Plugin_Hdbuserstore_Path}" -H "$(hostname)" DELETE "${Plugin_Backup_Key_Name}"
		local deleteKeyResult="${Plugin_Run_Command_Output}"
		local deleteKeyStatus="${Plugin_Run_Command_Status}"
		if [ "x${deleteKeyResult}" != "x" ] && [ "x${deleteKeyStatus}" != "x0" ]
		then
		{
			Logger.LogWarning "Failed to delete BACKUP_KEY_NAME: '${deleteKeyResult}'."
		}
		else
		{
			Logger.LogPass "Deleted BACKUP_KEY_NAME."
		}
		fi
	}

	Plugin.CreateUser()
	{
		Logger.LogInformation "Creating BACKUP_KEY_USER = '${Plugin_Backup_Key_User}'."
		local userPassword="$(tr -dc '0-9a-zA-Z@%^_=+.\-' < /dev/urandom | head -c 64)"
		Plugin.RunQueryAsSystem "CREATE USER ${Plugin_Backup_Key_User} PASSWORD \"${userPassword}\" NO FORCE_FIRST_PASSWORD_CHANGE"
		local createResult="${Plugin_Run_Query_Output}"
		[ "x${createResult}" != "x" ] && Logger.Exit Failure "Failed to create BACKUP_KEY_USER: '${createResult}'."
		Logger.LogPass "Created BACKUP_KEY_USER."

		Logger.LogInformation "Creating BACKUP_KEY_NAME = '${Plugin_Backup_Key_Name}'."
		Plugin.RunCommand unset HDB_USE_IDENT "&&" "${Plugin_Hdbuserstore_Path}" -H "$(hostname)" SET "${Plugin_Backup_Key_Name}" "localhost:${Plugin_Port_Number}" "${Plugin_Backup_Key_User}" "${userPassword}"
		local createKeyResult="${Plugin_Run_Command_Output}"
		local createKeyStatus="${Plugin_Run_Command_Status}"
		[[ "x${createKeyResult}" != "x" && "x${createKeyStatus}" != "x0" ]] && Logger.Exit Failure "Failed to create BACKUP_KEY_NAME: '${createKeyResult}'."
		Logger.LogPass "Created BACKUP_KEY_NAME."
	}

	Plugin.AlterUser()
	{
		Logger.LogInformation "Disabling password lifetime on BACKUP_KEY_USER = '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsSystem "ALTER USER ${Plugin_Backup_Key_User} DISABLE PASSWORD LIFETIME"
		local alterResult="${Plugin_Run_Query_Output}"
		[ "x${alterResult}" != "x" ] && Logger.Exit Failure "Failed to disable password lifetime on BACKUP_KEY_USER: '${alterResult}'."
		Logger.LogPass "Disabled password lifetime on BACKUP_KEY_USER."

		Logger.LogInformation "Resetting connection attempts on BACKUP_KEY_USER = '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsSystem "ALTER USER ${Plugin_Backup_Key_User} RESET CONNECT ATTEMPTS"
		local alterResult="${Plugin_Run_Query_Output}"
		[ "x${alterResult}" != "x" ] && Logger.Exit Failure "Failed to reset connection attempts on BACKUP_KEY_USER: '${alterResult}'."
		Logger.LogPass "Reset connection attempts on BACKUP_KEY_USER."

		Logger.LogInformation "Activating BACKUP_KEY_USER = '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsSystem "ALTER USER ${Plugin_Backup_Key_User} ACTIVATE USER NOW"
		local alterResult="${Plugin_Run_Query_Output}"
		[ "x${alterResult}" != "x" ] && Logger.Exit Failure "Failed to activate BACKUP_KEY_USER: '${alterResult}'."
		Logger.LogPass "Activated BACKUP_KEY_USER."
	}

	Plugin.LoginUser()
	{
		Logger.LogInformation "Checking login for BACKUP_KEY_USER = '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsBackup "SELECT CURRENT_USER FROM DUMMY"
		local checkResult="${Plugin_Run_Query_Output}"
		if [ "${checkResult^^}" != "${Plugin_Backup_Key_User^^}" ]
		then
		{
			Logger.LogWarning "Check failed: '${checkResult}'."
			Plugin_Login_User_Result=0
		}
		else
		{
			Logger.LogPass "Checked login."
			Plugin_Login_User_Result=1
		}
		fi
	}

	Plugin.GrantPrivilege()
	{
		Logger.LogInformation "Granting privilege '${1}' to '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsSystem "GRANT ${1} TO ${Plugin_Backup_Key_User}"
		local grantResult="${Plugin_Run_Query_Output}"
		[ "x${grantResult}" != "x" ] && Logger.Exit Failure "Failed to grant privilege: '${grantResult}'."
		Logger.LogPass "Granted privilege."
	}

	Plugin.GrantUser()
	{
		[ "${Plugin_Instance_Type}" == "MDC" ] && Plugin.GrantPrivilege "DATABASE ADMIN"
		[ "${Plugin_Instance_Type}" == "SDC" ] && Plugin.GrantPrivilege "BACKUP ADMIN"
		Plugin.GrantPrivilege "CATALOG READ"
		if [ "${Plugin_HSR_Primary}" -eq "1" ]
		then
		{
			Plugin.GrantPrivilege "INIFILE ADMIN"
		}
		fi
		Package.VersionCompare "${Plugin_Instance_Version}" "${Constant_Plugin_Min_Version_SAP_INTERNAL_HANA_SUPPORT_NOT_Required}"
		if [ "${Package_Version_Compare_Result}" -ne "0" ]
		then
		{
			Logger.LogInformation "INSTANCE_VERSION = '${Plugin_Instance_Version}': Required 'SAP_INTERNAL_HANA_SUPPORT' role."
			Plugin.GrantPrivilege "SAP_INTERNAL_HANA_SUPPORT"
		}
		fi
		Package.VersionCompare "${Plugin_Instance_Version}" "${Constant_Plugin_Min_Version_MDC_BACKUP_ADMIN_ROLE_Required}"
		if [ "${Package_Version_Compare_Result}" -eq "0" ]
		then
		{
			Plugin.GrantPrivilege "BACKUP ADMIN"
		}
		fi
	}

	Plugin.CheckPrivilege()
	{
		Logger.LogInformation "Checking privilege '${1}' on '${Plugin_Backup_Key_User}'."
		Plugin.RunQueryAsBackup "${2}"

		local expectedOuputBackupKeyUser=""
		[ "$#" -ge "3" ] && expectedOuputBackupKeyUser=${3}

		local checkResult="${Plugin_Run_Query_Output}"
		if [[ "x${checkResult}" != "x" &&  "x${expectedOuputBackupKeyUser}" == "x" ]]
		then
		{
			Logger.LogWarning "Check failed: '${checkResult}'."
			Plugin_Check_Privilege_Result=0
		}
		elif [[ "x${expectedOuputBackupKeyUser}" == "xtrue" && "${checkResult^^}" != "${Plugin_Backup_Key_User^^}" ]]
		then
		{
			Logger.LogWarning "Check failed: '${checkResult}'."
			Plugin_Check_Privilege_Result=0
		}
		else
		{
			Logger.LogPass "Checked privilege."
			Plugin_Check_Privilege_Result=1
		}
		fi
	}

	Plugin.CheckUser()
	{
		[ "${Plugin_Instance_Type}" == "MDC" ] && Plugin.CheckPrivilege "CATALOG READ" "SELECT BACKUP_ID FROM SYS_DATABASES.M_BACKUP_CATALOG WHERE STATE_NAME = 'DUMMY_STATE_NAME'"
		[ "${Plugin_Instance_Type}" == "SDC" ] && Plugin.CheckPrivilege "CATALOG READ" "SELECT BACKUP_ID FROM SYS.M_BACKUP_CATALOG WHERE STATE_NAME = 'DUMMY_STATE_NAME'"
		Plugin_Check_User_Result="${Plugin_Check_Privilege_Result}"
		[ "${Plugin_Check_User_Result}" -eq "0" ] && return
		
		Package.VersionCompare "${Plugin_Instance_Version}" "${Constant_Plugin_Min_Version_SAP_INTERNAL_HANA_SUPPORT_NOT_Required}"
		if [ "${Package_Version_Compare_Result}" -ne "0" ]
		then
		{
			Plugin.CheckPrivilege "SAP_INTERNAL_HANA_SUPPORT" "SELECT BACKUP_ID FROM SYS.M_DEV_BACKUP_CATALOG_LOG_ WHERE STATE_NAME = 'DUMMY_STATE_NAME'"
			Plugin_Check_User_Result="${Plugin_Check_Privilege_Result}"
			[ "${Plugin_Check_User_Result}" -eq "0" ] && return
		}
		fi
		
		Package.VersionCompare "${Plugin_Instance_Version}" "${Constant_Plugin_Min_Version_MDC_BACKUP_ADMIN_ROLE_Required}"
		if [ "${Package_Version_Compare_Result}" -eq "0" ]
		then
		{
			Plugin.CheckPrivilege "BACKUP ADMIN" "SELECT TOP 1 GRANTEE FROM EFFECTIVE_PRIVILEGE_GRANTEES WHERE OBJECT_TYPE = 'SYSTEMPRIVILEGE' AND PRIVILEGE = 'BACKUP ADMIN' AND GRANTEE ='${Plugin_Backup_Key_User}'" "true"
			Plugin_Check_User_Result="${Plugin_Check_Privilege_Result}"
			[ "${Plugin_Check_User_Result}" -eq "0" ] && return
		}
		fi
		if [ "${Plugin_HSR_Primary}" -eq "1" ]
		then
		{
			Plugin.CheckPrivilege "INIFILE ADMIN" "SELECT TOP 1 GRANTEE FROM EFFECTIVE_PRIVILEGE_GRANTEES WHERE OBJECT_TYPE = 'SYSTEMPRIVILEGE' AND PRIVILEGE = 'INIFILE ADMIN' AND GRANTEE ='${Plugin_Backup_Key_User}'" "true"
			Plugin_Check_User_Result="${Plugin_Check_Privilege_Result}"
			[ "${Plugin_Check_User_Result}" -eq "0" ] && return
		}
		fi


		[ "${Plugin_Instance_Type}" == "MDC" ] &&  Plugin.CheckPrivilege "DATABASE ADMIN" "SELECT TOP 1 GRANTEE FROM EFFECTIVE_PRIVILEGE_GRANTEES WHERE OBJECT_TYPE = 'SYSTEMPRIVILEGE' AND PRIVILEGE = 'DATABASE ADMIN' AND GRANTEE ='${Plugin_Backup_Key_User}'" "true"
		Plugin_Check_User_Result="${Plugin_Check_Privilege_Result}"
		[ "${Plugin_Check_User_Result}" -eq "0" ] && return
	}

	Plugin.ReadConfig()
	{
		Logger.LogInformation "Reading existing configuration."
		local result

		result="$("${Package_Python_Executable}" -c $'import json\n'"with open('${Constant_Plugin_Config_File_Old}', 'r') as config: print(len(json.load(config)))" 2>&1)"
		[ "${?}" -ne "0" ] && Logger.LogInformation "No valid existing configuration found." && return
		[ "${result}" -ne "1" ] && Logger.Exit Failure "More than one SID found in existing configuration: Not supported."

		result="$("${Package_Python_Executable}" -c $'import json\n'"with open('${Constant_Plugin_Config_File_Old}', 'r') as config: print(json.load(config)[0]['LogicalContainerId'])" 2>&1)"
		[ "${?}" -eq "0" ] && Plugin_Config_Sid="${result}" && Logger.LogInformation "Found SID = '${Plugin_Config_Sid}'."

		result="$("${Package_Python_Executable}" -c $'import json\n'"with open('${Constant_Plugin_Config_File_Old}', 'r') as config: print(json.load(config)[0]['LogicalContainerOSUser'])" 2>&1)"
		[ "${?}" -eq "0" ] && Plugin_Config_User="${result}" && Logger.LogInformation "Found USER = '${Plugin_Config_User}'."

		result="$("${Package_Python_Executable}" -c $'import json\n'"with open('${Constant_Plugin_Config_File_Old}', 'r') as config: print(json.load(config)[0]['PropertyBag']['odbcDriverPath'])" 2>&1)"
		[ "${?}" -eq "0" ] && Plugin_Config_Driver_Path="${result}" && Logger.LogInformation "Found DRIVER_PATH = '${Plugin_Config_Driver_Path}'."

		result="$("${Package_Python_Executable}" -c $'import json\n'"with open('${Constant_Plugin_Config_File_Old}', 'r') as config: print(json.load(config)[0]['PropertyBag']['hdbuserstoreKeyName'])" 2>&1)"
		[ "${?}" -eq "0" ] && Plugin_Config_Backup_Key_Name="${result}" && Logger.LogInformation "Found BACKUP_KEY_NAME = '${Plugin_Config_Backup_Key_Name}'."

		result="$("${Package_Python_Executable}" -c $'import json\n'"with open('${Constant_Plugin_Config_File_Old}', 'r') as config: print(json.load(config)[0]['PropertyBag']['isADUser'])" 2>&1)"
		[ "${?}" -eq "0" ] && Plugin_Config_AD_User="${result}" && Logger.LogInformation "Found AD_USER = '${Plugin_Config_AD_User}'."

		Logger.LogPass "Reading complete."
	}

	Plugin.WriteConfig()
	{
		Logger.LogInformation "Writing to configuration."

		mkdir -p "$(dirname "${Constant_Plugin_Config_File_Old}")"
		touch "${Constant_Plugin_Config_File_Old}"
		chown -R "${Constant_Msawb_User}:${Constant_Msawb_Group_Secondary}" "$(dirname "${Constant_Plugin_Config_File_Old}")"

		if [ "${Plugin_Mode}" == "add" ]
		then
		{

			local result
			[ "x${Plugin_HSR_Unique_Value}" == "x" ] && result="$("${Package_Python_Executable}" -c "
import json
obj=[
	{
		'LogicalContainerId': '${Plugin_Sid}',
		'LogicalContainerOSUser' : '${Plugin_User}',
		'PropertyBag':
		{
			'odbcDriverPath': '${Plugin_Driver_Path}',
			'hdbuserstoreKeyName': '${Plugin_Backup_Key_Name}',
			'encrypt':'${Plugin_Encrypt}',
			'sslKeyStore':'${Plugin_Ssl_Key_Store}',
			'sslTrustStore':'${Plugin_Ssl_Trust_Store}',
			'sslCryptoProvider':'${Plugin_Ssl_Crypto_Provider}',
			'sslHostNameInCertificate':'${Plugin_Host_Name_In_Certificate}',
			'sslValidateCertificate':'${Plugin_Ssl_Validate_Certificate}',
			'isADUser':'${Plugin_AD_User}'
		}
	}
]
with open('${Constant_Plugin_Config_File_Old}', 'w') as config:
	json.dump(obj, config, indent = 4, sort_keys = True)
" 2>&1)"

			[[ "x${Plugin_HSR_Unique_Value}" == "x" &&  "${?}" -ne "0" ]] && Logger.Exit Failure "Failed to write configuration: '${result}'."

			[ "x${Plugin_HSR_Unique_Value}" != "x" ] && result="$("${Package_Python_Executable}" -c "
import json
obj=[
	{
		'LogicalContainerId': '${Plugin_Sid}',
		'LogicalContainerOSUser' : '${Plugin_User}',
		'LogicalContainerHSRGuid' : '${Plugin_HSR_Unique_Value}',
		'PropertyBag':
		{
			'odbcDriverPath': '${Plugin_Driver_Path}',
			'hdbuserstoreKeyName': '${Plugin_Backup_Key_Name}',
			'encrypt':'${Plugin_Encrypt}',
			'sslKeyStore':'${Plugin_Ssl_Key_Store}',
			'sslTrustStore':'${Plugin_Ssl_Trust_Store}',
			'sslCryptoProvider':'${Plugin_Ssl_Crypto_Provider}',
			'sslHostNameInCertificate':'${Plugin_Host_Name_In_Certificate}',
			'sslValidateCertificate':'${Plugin_Ssl_Validate_Certificate}',
			'isADUser':'${Plugin_AD_User}'
		}
	}
]
with open('${Constant_Plugin_Config_File_Old}', 'w') as config:
	json.dump(obj, config, indent = 4, sort_keys = True)
" 2>&1)"

			[[ "x${Plugin_HSR_Unique_Value}" != "x" &&  "${?}" -ne "0" ]] && Logger.Exit Failure "Failed to write configuration: '${result}'."

		}
		elif [ "${Plugin_Mode}" == "remove" ]
		then
		{
			#In the future if we support multiple instance
			#delete only one entry instead of whole file.
			rm -f "${Constant_Plugin_Config_File_Old}"
		}
		fi

		Logger.LogPass "Writing complete."
	}

	Plugin.WriteEnvironment()
	{
		Logger.LogInformation "Writing to environment file."
		hostname=$(hostname)
		Plugin_Host_Environment_File="${Constant_Plugin_Environment_File//\{1\}/${Plugin_Sid,,}}"
		mkdir -p "$(dirname "${Plugin_Host_Environment_File}")"
		touch "${Plugin_Host_Environment_File}"
		chown -R "${Constant_Msawb_User}:${Constant_Msawb_Group_Secondary}" "$(dirname "${Plugin_Host_Environment_File}")"

		if [ "${Plugin_Mode}" == "add" ]
		then
		{
			local result
			[ "x${Plugin_Encrypt}" == "x" ] && result="$(printf "%b" "TINSTANCE=${Plugin_Instance_Number}\n" "LD_LIBRARY_PATH=${Plugin_Ld_Library_Path}\n" > ${Plugin_Host_Environment_File})"
			[[ "x${Plugin_Encrypt}" == "x" &&  "${?}" -ne "0" ]] && Logger.Exit Failure "Failed to write environment file: '${result}'."
			[ "x${Plugin_Encrypt}" == "xtrue" ] && result="$(printf "%b" "TINSTANCE=${Plugin_Instance_Number}\n" "LD_LIBRARY_PATH=${Plugin_Ld_Library_Path}\n" "SECUDIR=${Plugin_Secudir}\n" "HOME=${Plugin_Home}\n" > ${Plugin_Host_Environment_File})"
			[[ "x${Plugin_Encrypt}" == "xtrue" && "${?}" -ne "0" ]] && Logger.Exit Failure "Failed to write environment file: '${result}'."
		}
		elif [ "${Plugin_Mode}" == "remove" ]
		then
		{
			rm -f "${Plugin_Host_Environment_File}"
		}
		fi

		Logger.LogPass "Writing complete."
	}

	Plugin.AddSupplementaryGroupToUser()
	{
		Logger.LogInformation "Adding user '${Plugin_User}' to group '${Constant_Msawb_Group_Secondary}'."
		local result && result="$(gpasswd --add "${Plugin_User}" "${Constant_Msawb_Group_Secondary}" 2>&1)"
		[ "${?}" -eq "0" ] && Logger.LogPass "Successfully added user." && return
		Logger.Exit Failure "Failed to add user: '${result}'."
	}

	Plugin.CheckIfUserIsAddedToGroup()
	{
		Logger.LogInformation "Checking if user '${Plugin_User}' is added to group '${Constant_Msawb_Group_Secondary}'."
		local result && result="$(id "${Plugin_User}" | grep -o "${Constant_Msawb_Group_Secondary}" 2>&1)"
		[ "${?}" -eq "0" ] && [ "${result}" == "${Constant_Msawb_Group_Secondary}" ] && Logger.LogPass "User is already added to group." && return
		Logger.Exit Failure "AD user '${Plugin_User}' is not added to ${Constant_Msawb_Group_Secondary} group. Create a group '${Constant_Msawb_Group_Secondary}' in your active directory, add '${Plugin_User}' to it and re-run the script with -ad option."
	}

	Plugin.RemoveSupplementaryGroupFromUser()
	{
		Logger.LogInformation "Removing user '${Plugin_User}' from group '${Constant_Msawb_Group_Secondary}'."
		local result && result="$(gpasswd --delete "${Plugin_User}" "${Constant_Msawb_Group_Secondary}" 2>&1)"
		[ "${?}" -eq "0" ] && Logger.LogPass "Successfully removed user." && return
		Logger.Exit Failure "Failed to remove user: '${result}'."
	}

	Plugin.Help()
	{
		cat <<- Plugin_Help_EOF
			Usage: ${Constant_Script_Name} [command] [parameters]

			command:

			  -h, --help
			    Display this information.

			  -v, --version
			    Display version information.

			  -a, --add
			    Add a HANA server to Azure Workload Backup. This is the default command.
			    Any unspecified parameters will be attempted for automatic detection.
			    This command must be run before further steps like machine registration,
			    database discovery and protection.

			  -r, --remove
			    Remove a HANA server from Azure Workload Backup.
			    The --sid parameter must be the only parameter supplied with this command.
			    This command must be run after stopping protection of all databases and
			    unregistering the machine from Azure Workload Backup.

			  -us, --update-script
			    Update this script by downloading the latest version from Microsoft servers.
			    No parameters must be specified with this command.

			parameters:

			  -s SID, --sid SID
			    Specify the system identifier of the HANA server.
			    This is an uppercase alphanumeric string of length 3.
			    The system must be installed at "/usr/sap/<SID>".

			  -n INSTANCE_NUMBER, --instance-number INSTANCE_NUMBER
			    Specify the instance number of the HANA server.
			    This is a 2-digit zero-padded string i.e. "00" to "99".
			    The instance must be installed at "/usr/sap/<SID>/HDB<INSTANCE_NUMBER>".

			  -sk SYSTEM_KEY_NAME, --system-key SYSTEM_KEY_NAME
			    Specify the hdbuserstore key name for the SYSTEM account of the HANA server.
			    This is automatically determined and needs to be specified only to either
			    override the first match in case there are multiple keys suitable for the
			    instance or you want to specify a non-SYSTEM account key which has create
			    user and grant privilege permissions on the HANA server. In case your server
			    is an MDC instance, the key must point to the nameserver and the SYSTEMDB.
			    Neither this parameter nor the presence of the key are necessary as long as
			    the script verfies that the backup key is already valid and suitable for use
			    with Azure Workload Backup.

			  -bk BACKUP_KEY_NAME, --backup-key BACKUP_KEY_NAME
			    Specify the hdbuserstore key name for the backup account of the HANA server.
			    This is automatically determined by searching in the existing configuration
			    and then for a key with the user '${Constant_Plugin_Default_Backup_Key_User}'
			    and then for a key with the name '${Constant_Plugin_Default_Backup_Key_Name}'.
			    A custom key name with a custom user can be specified instead to override it.
			    In case your server is an MDC instance, the key must point to the nameserver
			    and the SYSTEMDB. During an add command, if a key with this name doesn't exist
			    already, it is created with this name and the user '${Constant_Plugin_Default_Backup_Key_User}'.
			    If a key already exists with this name, it is verfied for use with Azure
			    Workload Backup. If the verification fails and this key points to the user
			    '${Constant_Plugin_Default_Backup_Key_User}', then the key and the user are
			    attempted for automatic re-creation. If the verification fails and the key
			    points to a different user, then the script fails naming the missing privilege.

			  -sn, --skip-network-checks
			    Specify this switch to skip outbound network connectivity checks.

			  -sks SSL_KEY_STORE, --sslkeystore SSL_KEY_STORE
			    Specify the name of the keystore file that contains the client's identity (eg. sapsrv.pse).
			    The script will search for the file in the appropriate directory depending on the cryptoprovider mentioned.
			    If this argument is not provided, it is automatically determined by searching in the configuration files.
				
			  -sts SSL_TRUST_STORE, --ssltruststore SSL_TRUST_STORE
			    Specify the name of the trust store file that contains the server’s public certificates (eg. sapsrv.pse).
			    The script will search for the file in the appropriate directory depending on the cryptoprovider mentioned.
			    If this argument is not provided, it is automatically determined by searching in the configuration files.

			  -scp SSL_CRYPTO_PROVIDER, --sslcryptoprovider SSL_CRYPTO_PROVIDER
			    Specify the cypto provider being used (commoncrypto/openssl).
			    If this argument is not provided, it is automatically determined by searching in the configuration files.

			  -sh SSL_HOST_NAME_IN_CERTIFICATE, --sslhostnameincertificate SSL_HOST_NAME_IN_CERTIFICATE
			    Specify the hostname as mentioned in the SSL certificate.
			    If this argument is not provided, it is automatically determined by searching in the SSL certificate.

			  -svc SSL_VALIDATE_CERTIFICATE, --sslvalidatecertificate
			    Specify this switch to validate the certificate of the communication partner.

			  -ad AD_USER, --ad-user AD_USER
			    Specify this switch if HANA is installed with an AD <sid>adm user.
			    Create an AD '${Constant_Msawb_Group_Secondary}' group in your active directory and add the <sid>adm user to the '${Constant_Msawb_Group_Secondary}' group before
			    running the script using this option.  

		Plugin_Help_EOF
		Logger.Exit
	}

	Plugin.Version()
	{
		cat <<- Plugin_Version_EOF
			${Constant_Script_Name} ${Constant_Script_Version}
			Microsoft Azure Workload Backup plugin configuration script for ${Constant_Plugin_Name}.
			Copyright (C) Microsoft Corporation. All rights reserved.
		Plugin_Version_EOF
		Logger.Exit
	}
}

Main()
{
	{
		Constant
		Errno
		Logger
		Package
		Check
		Plugin
	}

	Main.CreateGroupIfNotExists()
	{
		Logger.LogInformation "Creating group '${Constant_Msawb_Group_Secondary}'."
		local result="$(awk -F ':' "\$1 == \"${Constant_Msawb_Group_Secondary}\" { print \$1 }" /etc/group)"
		[ "${result}" == "${Constant_Msawb_Group_Secondary}" ] && Logger.LogPass "Group already exists." && return
		result="$(groupadd "${Constant_Msawb_Group_Secondary}" 2>&1)"
		[ "${?}" -eq "0" ] && Logger.LogPass "Successfully created group." && return
		Logger.Exit Failure "Failed to create group: '${result}'."
	}

	Main.UpdateScript()
	{
		local newScriptTempPath="${Constant_Script_Path}.new"
		Logger.LogInformation "Downloading server script version to '${newScriptTempPath}'."
		local response && response="$(curl --silent --output "${newScriptTempPath}" --location --request GET "${Constant_Script_Source_Url}" --write-out "%{http_code}\n")"
		local status="${?}"
		[ "${status}" -ne "0" ] && Logger.Exit Failure "Failed to download: Received from curl: '${status}'."
		[ "${response}" != "200" ] && Logger.Exit Failure "Failed to download: Received from service: 'HTTP/${response}'."
		Logger.LogPass "Successfully downloaded."
		chmod +x "${newScriptTempPath}"
		Logger.LogInformation "Current script version is '${Constant_Script_Version}'."
		Logger.LogInformation "Server script version is '$("${newScriptTempPath}" --version | head -n 1 | cut -d ' ' -f 2)'."
		Logger.LogInformation "Replacing the current script with the server version."
		mv "${newScriptTempPath}" "${Constant_Script_Path}" || Logger.Exit Failure "Failed to replace: '${?}'."
		Logger.LogPass "Replaced."
	}

	Main.DeleteGroupIfEmpty()
	{
		Logger.LogInformation "Deleting group '${Constant_Msawb_Group_Secondary}'."
		local result="$(awk -F ':' "\$1 == \"${Constant_Msawb_Group_Secondary}\" { print \$4 }" /etc/group)"
		[ "x${result}" != "x" ] && Logger.LogPass "Group not empty." && return
		result="$(groupdel "${Constant_Msawb_Group_Secondary}" 2>&1)"
		[ "${?}" -eq "0" ] && Logger.LogPass "Successfully deleted group." && return
		Logger.LogWarning "Failed to delete group: '${result}'."
	}

	Main.Parse()
	{
		Plugin.Parse "${@}"
		Check.User

		case "${Plugin_Mode}" in
			"update-script")
			{
				# RequirePython needs to be at the top of Package.Require
				# to setup the correct python executable
				Package.RequirePython
				Package.Require Curl
				Main.UpdateScript
			};;

			"add")
			{
				Check.OS
				Check.FreeSpace
				Check.Hostnames

				# RequirePython needs to be at the top of Package.Require
				# to setup the correct python executable
				Package.RequirePython
				Package.Require WaAgent
				Package.Require Curl
				Package.Require Libicu "true"
				Package.Require Unzip "true"

				Check.Waagent
				Check.PythonXMLReq
				Check.Wireserver
				Check.IMDS

				if [ "${Plugin_Skip_Network_Checks}" -eq "0" ]
				then
				{
					Check.AadConnectivity
					Check.ServiceConnectivity
				}
				else
				{
					Logger.LogWarning "Skipping outbound network connectivity checks."
				}
				fi

				if [ "x${Plugin_AD_User}" == "xfalse" ]
				then
				{
					Main.CreateGroupIfNotExists
				}
				else
				{
					Logger.LogWarning "Skipping creation of '${Constant_Msawb_Group_Secondary}' group."
				}
				fi

				Plugin.Run
			};;

			"remove")
			{
				Check.Hostnames

				Package.RequirePython

				Plugin.Run
				Main.DeleteGroupIfEmpty
			};;
		esac

		Logger.Exit Success
	}
}

Main
Main.Parse "${@}"
