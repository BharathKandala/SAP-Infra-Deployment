from __future__ import print_function
from __future__ import absolute_import
import os, time, sys, subprocess, getopt, threading
import ConfigMgrPy

class MDCConversionError(Exception):

    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class MDCConversion:
    dbname = ConfigMgrPy.sapgparam("SAPSYSTEMNAME")
    verbose = 0

    def isMultiDBInstance(self):
        globalCustomerConfig = ConfigMgrPy.LayeredConfiguration('global.ini', ConfigMgrPy.CUSTOMER)
        if globalCustomerConfig.getStringValue('multidb','mode').lower() == 'multidb':
            return True
        else:
            return False

    def usage(self):
        print("convertMDC.py [--help] [--force] [--nostart] [--verbose] [--change={mode|databaseIsolation}] [--isolation=(low|high)]")
        print("\t --help print usage")
        print("\t --verbose print verbose log information")
        print("\t --change={mode|databaseIsolation} defines the change that is executed (default=mode)")
        print("\t\t mode will change the multidb mode from single into multidb")
        print("\t !!!THIS will REINITIALIZE the SYSTEMDB persistence, all data will be lost!!!")
        print("\t\t databaseIsolation will change the multidb databaseIsolation mode high <-> low")
        print("\t --force do the conversion even if the instance is already in multidb mode.")
        print("\t --isolation=<level> sets the database isolation to the respective level (default: low)")
        print("\t --nostart does not start the instance after conversion")

    def main(self, argv):
        force = False
        isolation = None
        action = None
        catalogMove = True
        catalogFileName = None
        licenseMove = True
        licenseFileName = None
        topologyFileName = None
        resetUserSystem = True
        noStart = False
        try:
            opts, args = getopt.getopt(argv, "vhfnsbli:c:", ["force","help","nostart","verbose", "change=", "isolation=", "backupCatalogDisable", "withBackupCatalog=", "licenseDisable", "withLicense=", "withTopology=", "systemUserResetDisable"])
            for opt, arg in opts:
                if opt in ('-h', '--help'):
                    self.usage()
                    return 0
                if opt in ('-f', '--force'):
                    force = True
                if opt in ('-n', '--nostart'):
                    noStart = True
                if opt in ('-v', '--verbose'):
                    self.verbose += 1
                if opt in ('-i', '--isolation'):
                    isolation = arg.lower()
                    if isolation != "high" and isolation != 'low':
                        raise MDCConversionError('ERROR: Unkown isolation mode: %s' % (arg))
                if opt in ('-c', '--change'):
                    action = arg
                    if action != "mode" and action != 'databaseIsolation':
                        raise MDCConversionError('ERROR: Unkown change mode: %s' % (arg))
                if opt in ('-b', '--backupCatalogDisable'):
                    catalogMove = False
                if opt in ('-l', '--licenseDisable'):
                    licenseMove = False
                if opt in ('--withBackupCatalog'):
                    catalogFileName = "=%s"%arg
                if opt in ('--withLicense'):
                    licenseFileName = "=%s"%arg
                if opt in ('--withTopology'):
                    topologyFileName = "=%s"%arg
                if opt in ('-s', '--systemUserResetDisable'):
                    resetUserSystem = False

            if action is None:
                self.usage()
                raise MDCConversionError('ERROR: missing mandatory argument --change=...')

            if action == 'databaseIsolation':
                if not catalogMove:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --change=databaseIsolation and --backupCatalogDisable')

                if not licenseMove:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --change=databaseIsolation and --licenseDisable')

                if force:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --change=databaseIsolation and --force')

                if not resetUserSystem:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --change=databaseIsolation and --systemUserResetDisable')

                if licenseFileName is not None:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --withLicense= and --change=databaseIsolation')

                if catalogFileName is not None:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --withBackupCatalog= and --change=databaseIsolation')

                if topologyFileName is not None:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --change=databaseIsolation and --withTopoloby')

                if isolation is None:
                    isolation = "low"
            else:
                if isolation is not None:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --isolation= and --change=mode')

                if licenseFileName is not None and not licenseMove:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --withLicense= and --licenseDisable')
                elif licenseFileName is None and licenseMove:
                    licenseFileName = ""

                if catalogFileName is not None and not catalogMove:
                    self.usage()
                    raise MDCConversionError('ERROR: Invalid option combination --withBackupCatalog= and --backupCatalogDisable')
                elif catalogFileName is None and catalogMove:
                    catalogFileName = ""

            self.convertToMDCInstance(resetUserSystem = resetUserSystem, forceConversion = force, changeAction=action, isolationLevel = isolation, backupCatalogFileName = catalogFileName, licenseFileName = licenseFileName, topologyFileName = topologyFileName, noStart = noStart)
            return 0
        except getopt.GetoptError:
            self.usage()
            return 1
        except MDCConversionError as err:
            print(err)
        return 1

    def __getOwnHostname(self):
        try:
            srp = os.environ["SAP_RETRIEVAL_PATH"].split(os.path.sep)
            hostname = srp[len(srp) - 1]
        except KeyError:
            raise Exception("SAP_RETRIEVAL_PATH is not set!")

        return hostname

    def __getMasterHostname(self):

        config = ConfigMgrPy.LayeredConfiguration('nameserver.ini', ConfigMgrPy.READONLY)
        master = config.getStringValue('landscape','active_master')
        if not master:
            raise MDCConversionError("nameserver.ini [landscape] active_master is not set!")
        host,port = master.split(':')

        return host

    def __checkOnMaster(self, forceConversion):
        ownHost = self.__getOwnHostname()
        masterHost = self.__getMasterHostname()

        if ownHost != masterHost:
            if forceConversion:
                print("ConvertMDC.py should be executed the master host %s; due to -f this is ignored" %masterHost)
            else:
                raise MDCConversionError("convertMDC.py must be executed on master host %s, this host %s"%(masterHost, ownHost))

    def convertToMDCInstance(self, resetUserSystem = False, forceConversion = False, changeAction = "mode", isolationLevel = None, backupCatalogFileName="", licenseFileName="", topologyFileName = None, noStart = False):

        if changeAction == 'databaseIsolation':
            # check for multidb mode
            if not self.isMultiDBInstance():
                raise MDCConversionError("Error: Instance %s not in MDC mode" % self.dbname)
        else:
            # check for none multidb mode
            if self.isMultiDBInstance() and not forceConversion:
                raise MDCConversionError("Error: Instance %s already in MDC mode" % self.dbname)

        systemReplicationActive = False
        isPrimary = False
        globalCustomerConfig = ConfigMgrPy.LayeredConfiguration('global.ini', ConfigMgrPy.CUSTOMER)
        if globalCustomerConfig.hasSection('system_replication'):
            if globalCustomerConfig.getStringValue('system_replication', 'actual_mode', '').lower() == 'primary':
                systemReplicationActive = True
                isPrimary = True
            else:
                if globalCustomerConfig.hasSection('system_replication_site_masters'):
                    systemReplicationActive = True

        if changeAction == 'mode':
            # check master again to avoid unnecessary stop
            self.__checkOnMaster(forceConversion)
        elif changeAction == 'databaseIsolation' and systemReplicationActive:
            raise MDCConversionError("Error: Instance %s is in system replication, can not change isolation level" % self.dbname)

        print("Stop System")
        self.stopSystem()

        if changeAction == 'mode':

            globalCustomerConfig.removeValue('multidb', 'database_isolation')

            # check master again maybe something has changed
            self.__checkOnMaster(forceConversion)
            args = ["-convertToMultiDB"]

            if not systemReplicationActive:
                if backupCatalogFileName is not None:
                    args.append("--withBackupCatalog%s"%backupCatalogFileName)

                if licenseFileName is not None:
                    args.append("--withLicense%s"%licenseFileName)

                if topologyFileName is not None:
                    args.append("--withTopology%s"%topologyFileName)
            else:
                args.append("--systemReplication")
                if not resetUserSystem:
                    args.append("--noResetUserSystem")

            if forceConversion:
                args.append("--forceConversion")

            print("Convert Topology to MDC")
            args.append("--phaseConvert")
            try:
                redirect = True
                if systemReplicationActive and resetUserSystem and sys.platform == 'linux2':
                    redirect = False
                    os.system("stty -echo")
                CommandLineUtil.starthdbnsutil(args=args, redirect=redirect)
            finally:
                if systemReplicationActive and resetUserSystem and sys.platform == 'linux2':
                    os.system("stty echo")

            args.pop()

            globalCustomerConfig.reload()

            if not systemReplicationActive:
                print("Reinit NameServerPersistence")
                args.append("--phaseReinit")
                CommandLineUtil.starthdbnsutil(args=args)

                if resetUserSystem:
                    print("start hdbnameserver to set password for user SYSTEM")
                    CommandLineUtil.starthdbnameserver(args = ["-resetUserSystem"])

        if isolationLevel is not None:
            if isolationLevel == 'high':
                print("Set database Isolation high")
                globalCustomerConfig.setStringValue('multidb', 'database_isolation', isolationLevel)
            else:
                print("Set database Isolation low")
                globalCustomerConfig.removeValue('multidb', 'database_isolation')

        if not noStart:
            print("Start System")
            self.startSystem()

        if changeAction == 'databaseIsolation':
            print("Database Isolation level change done")
            print("Tenants can now be changed and started by execution:")
            if isolationLevel == 'high':
                print("\t1. \"ALTER DATABASE <tenantName> OS USER '<osuser>' OS GROUP '<osgroup>'\"")
            else:
                print("\t1. \"ALTER DATABASE <tenantName> OS USER '' OS GROUP ''\"")
            print("\t2. \"ALTER SYSTEM START DATABASE <tenantName>\"")
        else:
            print("Conversion done")

            if not systemReplicationActive or isPrimary:
                print("Please reinstall delivery units into the SYSTEMDB.")
                if isolationLevel == 'high':
                    print("Tenant %s can now be changed and started by execution:" % (self.dbname))
                    print("\t1. \"ALTER DATABASE %s OS USER '<osuser>' OS GROUP '<osgroup>'\"" % (self.dbname))
                    print("\t2. \"ALTER SYSTEM START DATABASE %s\"" % (self.dbname))

    def stopSystem(self):
        return CommandLineUtil.stopSystem(self.verbose != 0)
    def startSystem(self):
        return CommandLineUtil.startSystem(self.verbose != 0)
    def starthdbnsutil(self, args):
        return CommandLineUtil.starthdbnsutil(args)
    def starthdbnameserver(self, args):
        return CommandLineUtil.starthdbnameserver(args)
    def executeCommand(self, path, command, args, checkReturnCode = True, redirect = True):
        return CommandLineUtil.executeCommand(path, command, args, checkReturnCode, redirect, 0, self.verbose != 0)


class CommandLineUtil:
    verbose = 0
    instance = None
    host = None
    sid = None
    exepath = None
    sapcontrol = None
    timeout = 600
    mutex = threading.Lock()

    def __init__(self):
        try:
            srp = os.environ["SAP_RETRIEVAL_PATH"].split(os.path.sep)
            self.exepath = os.environ['DIR_INSTANCE']

            if os.environ.get('USE_HDBCOV') is not None or os.environ.get('IQDIR16') is not None:
                self.timeout = 1200

        except KeyError:
            raise MDCConversionError("SAP_RETRIEVAL_PATH is not set!")

        if len(self.exepath) == 0:
            raise MDCConversionError("DIR_INSTANCE is not set!")

        self.sid = srp[-3]
        self.instance = int((srp[-2])[3:])
        self.host = srp[-1]
        self.sapcontrol = os.path.join("exe", "sapcontrol")

    def getInstanceID(self):
        return self.instance

    def getSID(self):
        return self.sid

    def getHost(self):
        return self.host

    def getSAPControl(self):
        return self.sapcontrol

    def getExePath(self):
        return self.exepath

    @staticmethod
    def __lock():
        CommandLineUtil.mutex.acquire(True)

    @staticmethod
    def __unlock():
        CommandLineUtil.mutex.release()

    def executeSAPControl(self, args, doThrow, verbose, expectedRc, checkSapStartSrv):
        if checkSapStartSrv and not self.startAndWaitForSapStartSrv():
            if doThrow:
                raise MDCConversionError("sapstartsrv is not running!")
            return False
        CommandLineUtil.__lock()
        try:
            argsx = ["-prot", "PIPE", "-nr", "%i"%self.getInstanceID(), "-function"] + args
            o,e,r = CommandLineUtil.executeCommand(path = self.getExePath(), command = self.getSAPControl(), args = argsx, checkReturnCode=doThrow, redirect = True, expectedRc = expectedRc, verbose = verbose)
        finally:
            CommandLineUtil.__unlock()
        return o,e,r

    def isHostStopped(self):
        args = ["GetProcessList"]
        _, _,rc = self.executeSAPControl(args, False, 0, 4, True)
        return rc == 4

    def isHostStarted(self):
        args = ["GetProcessList"]
        _, _,rc = self.executeSAPControl(args, False, 0, 3, True)
        return rc == 3

    def getSystemInstanceListState(self):
        args = ["GetSystemInstanceList"]
        out, _,rc = self.executeSAPControl(args, False, 0, 0, True)

        hostlineList = []
        if rc == 0:
            parse = False
            for each in out.split('\n'):
                line = each.strip()
                if line:
                    if parse:
                        hostlineList.append(line)
                    elif line.startswith('hostname,'):
                        parse = True
        return hostlineList

    def isSingleHost(self):
        hosts = 0
        triesleft = 5
        while hosts == 0 and triesleft != 0:
            if triesleft < 5:
                time.sleep(5)
            hosts = len(self.getSystemInstanceListState())
            triesleft -= 1

        if hosts == 0:
            raise MDCConversionError("No system list found")

        return hosts == 1

    def waitForSapStartSrv(self, timeout, delay):
        args = ["WaitforServiceStarted", "%i"%timeout, "%i"%delay]
        _, _,rc = self.executeSAPControl(args, False, 0, 0, False)
        return rc == 0

    def startAndWaitForSapStartSrv(self):
        if self.waitForSapStartSrv(5, 0):
            return True
        args = ["StartService", self.getSID() ]
        _, _,rc = self.executeSAPControl(args, False, 1, 0, False)
        if rc != 0:
            return False
        return self.waitForSapStartSrv(120, 10)

    def waitStoppedSingleHost(self):
        args = ["WaitforStopped", "%i"%self.timeout, "2"]
        self.executeSAPControl(args, True, 1, 0, True)

    def waitStartedSingleHost(self):
        args = ["WaitforStarted", "%i"%self.timeout, "2"]
        self.executeSAPControl(args, True, 1, 0, True)

    def waitForStateMultiHost(self, verbose, checkState, hitCount):
        elapsed = 0
        sleeptime = 0
        matched = 0

        while elapsed < self.timeout:
            if sleeptime != 0:
                time.sleep(sleeptime)
            elapsed += sleeptime
            states = self.getSystemInstanceListState()

            if verbose:
                print("Waiting for system to become state %s. Current state:" % (checkState))
                for state in states:
                    print(state)

            allMatched = len(states) != 0
            for state in states:
                if not state.endswith(checkState):
                    allMatched = False
                    break

            if not allMatched:
                sleeptime = 10
                matched = 0
                continue

            matched += 1
            if hitCount == matched:
                return
            sleeptime = 2

        for state in states:
            print(state)
        raise MDCConversionError("Timeout wait system.")

    def waitStoppedMultiHost(self, verbose):
        self.waitForStateMultiHost(verbose, 'GRAY', 2)

    def waitStartedMultiHost(self, verbose):
        self.waitForStateMultiHost(verbose, 'GREEN', 1)

    def waitStopped(self, verbose):
        if self.isSingleHost():
            self.waitStoppedSingleHost()
        else:
            self.waitStoppedMultiHost(verbose)

    def waitStarted(self, verbose):
        if self.isSingleHost():
            self.waitStartedSingleHost()
        else:
            self.waitStartedMultiHost(verbose)

    def _stopSystem(self, printState = True):
        args = ["StopSystem", "ALL", "600", "600"]
        self.executeSAPControl(args, True, 1, 0, True)
        self.waitStopped(printState)

    def _startSystem(self, printState = True):
        args = ["StartSystem", "ALL"]
        self.executeSAPControl(args, True, 1, 0, True)
        self.waitStarted(printState)

    def _getProcessList(self, verbose, expectedRc):

        args = ["GetProcessList"]
        out, _, rc = self.executeSAPControl(args, expectedRc != -1, verbose, expectedRc, True)

        processList = []
        parse = False
        for each in out.split('\n'):
            line = each.strip()
            if line:
                if parse:
                    processList.append(line)
                elif line.startswith('name, description, dispstatus, textstatus, starttime, elapsedtime, pid'):
                    parse = True
        return rc, processList

    @staticmethod
    def getProcessList(verbose=0, expectedRc=-1):
        util = CommandLineUtil()
        return util._getProcessList(verbose, expectedRc)

    @staticmethod
    def stopSystem(printState = True):
        util = CommandLineUtil()
        util._stopSystem(printState)

    @staticmethod
    def startSystem(printState = True):
        util = CommandLineUtil()
        util._startSystem(printState)

    @staticmethod
    def starthdbnsutil(args, checkReturnCode = True, redirect = True):
        command = "hdbnsutil"
        if "DEV_PATH" in os.environ:
            path = os.environ['DEV_PATH']
        else:
            path = os.environ['DIR_EXECUTABLE']
        if not path:
            raise MDCConversionError('ERROR: Path to executable unknown, aborting...')

        return CommandLineUtil.executeCommand(path, command, args, checkReturnCode, redirect, 0, 1)

    @staticmethod
    def starthdbnameserver(args):
        command = "hdbnameserver"
        if "DEV_PATH" in os.environ:
            path = os.environ['DEV_PATH']
        else:
            path = os.environ['DIR_EXECUTABLE']
        if not path:
            raise MDCConversionError('ERROR: Path to executable unknown, aborting...')

        try:
            if sys.platform == 'linux2':
                os.system("stty -echo")
            CommandLineUtil.executeCommand(path, command, args, False, False, 0, 1)
        finally:
            if sys.platform == 'linux2':
                os.system("stty echo")

    @staticmethod
    def executeCommand(path, command, args, checkReturnCode = True, redirect = True, expectedRc = 0, verbose = 0):
        process = None
        cmdArgs = [os.path.join(path, command)]
        cmdArgs += args
        if CommandLineUtil.verbose > 0 or verbose > 0:
            print("Execute %s" % cmdArgs)
        if redirect:
            process = subprocess.Popen(cmdArgs, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            process = subprocess.Popen(cmdArgs)

        completeOutput = process.communicate()

        stderr = None
        stdout = None

        if redirect:
            stdout = completeOutput[0].decode('utf-8', 'replace')
            stderr = completeOutput[1].decode('utf-8', 'replace')

            #print ("Child %s returned with %s" %(process.pid, process.returncode))

            if process.returncode != expectedRc or CommandLineUtil.verbose > 1 or verbose > 1:
                if CommandLineUtil.verbose == 0 and verbose == 0:
                    print("Execute %s expected rc: %i" %(cmdArgs, expectedRc))
                #print output and error
                print("RETURN CODE:")
                print(process.returncode)
                print("OUT BEGIN:")
                print(stdout)
                print("OUT END")
                print("ERROR BEGIN")
                print(stderr)
                print("ERROR END")

        if checkReturnCode and process.returncode != expectedRc:
            raise MDCConversionError("%s with args %r failed!" % (command, cmdArgs))

        return stdout,stderr,process.returncode

if __name__ == '__main__':
    sys.exit(MDCConversion().main(sys.argv[1:]))


