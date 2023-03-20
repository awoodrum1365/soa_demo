#!/bin/bash  
# Application:  Synkros
# Project:      KonamiWeb
# Title:        Konami Web Docker Installation Script
# Version:      4.0.10
# Copyright:    Copyright 2021
# Author:       Steven Christman
# Company:      Konami Gaming, Inc. - Systems R&D
# Description:  Builds files required to KonamiWeb
# 
# 30-Dec-2021  SMC   RM #: Born on dating

#Global Variables
config_fileVersion=1.00
config_synkrosVersion=""
config_server_host=""
config_db_host="dev001.kgisystems.com"
config_db_port=1521
config_db_instance="ems4010s"
config_kweb_apiPort=8443
config_kweb_adminPort=8444
config_kweb_bridge=false
config_kweb_memory=512
config_kweb_args=""
config_iware_webPort=8001
config_iware_cmdPort=8002
config_iware_mobilePort=7002 
config_rabbitmq_enable=true
config_rabbitmq_mqPort=5673
config_rabbitmq_adminPort=15673
config_ui_monitor_port=8080
config_ui_monitor_sslPort=8081
installDirectory=""
iwareConfigDirectory=""
iwareLogsDirectory=""
iwareBinDirectory=""
konamiWebCertsDirectory=""
konamiWebSSLDirectory=""
konamiWebConfigDirectory=""
konamiWebLogsDirectory=""
konamiWebBinDirectory=""
konamiWebStoresDirectory=""
rabbitMQLogsDirectory=""
synkUIConfigDirectory=""
synkUILogsDirectory=""
synkrosUIDirectory=""
synkrosHelpDirectory=""
synk31Directory=""
htmlDirectory=""
readMeDirectory=""
useDispatch=false
useSynk31=false
useSMS=false
needIWare=false
appendToCompose=false
certificate_domain="fedev.kgisystems.com"
certificate_organizationName="Konami Gaming"
certificate_location="Las Vegas"
certificate_state="NV"
certificate_country="US"
certificate_organizationalUnit="Konami Support"
certificate_email="christman0909@konamigaming.com"
certificate_commonName="fedev"
certificate_ca_key_pass=netpass1
certificate_pkcs12_export_pass=netpass1
certificate_keystore_pass=netpass1
certificateDirectory=""
hasServerName=false
storesDirectory=""
certificate_create=false
alreadyCreatedCertificate=false
iware_smsFromNumber=""
iware_smsAccountSID=""
iware_smsAuthToken=""


main() {
	installationHeader
	echo -e "${Color_Off}Starting Installation... " 
	checkAndInstallDocker
	
	# Check if there was any arguments passed in
	if [ $# -eq 0 ]; then
		echo -e "\n${BRed}No Configuration files passed to installer. Exiting install.${Color_Off}"
		exit 
	else
		#arguments passed in so try to process each arguement as an input file. 
		for fileArgument in "$@"
		do
			buildInstanceWithFile "$fileArgument"
		done
	fi
	runDockerCompose
	echo -e "\n${Color_Off}Konami API Server Installation...${BGreen}Complete" 
	echo -e "${bYellow}Docker has attempted to start all Konami services. Please give a few minutes for each service to fully boot up. Refer to readme to learn more." 
	echo -e "${Color_Off}================================================================";
}

buildInstanceWithFile(){
	#check if file exists
	if [ -f "$1" ]; then
		echo -e "${Color_Off}\nConfiguration file ${BGreen}$1${Color_Off} found"
	else 
		echo -e "${Color_Off}\nConfiguration file ${BGreen}$1${Color_Off} does not exist"
		exit
	fi
	#Method to get settings from file
	getInputFromFile "$1"
	checkConfigCompatibility "$1"
	
	if [[ $certificate_create == true && $alreadyCreatedCertificate == false ]]; then
		outputCertificateConfiguration
		createCertificate
	elif [[ $certificate_create == true &&  $alreadyCreatedCertificate == true ]]; then
		echo -e "\n${Color_Off}Certificate Configuration based on input...\n"
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Create Certificate is	\"${BYellow}$certificate_create${Color_Off}\"" 
		echo -e "${Color_Off}Certificates have already been created during this install..."
	else 
		echo -e "\n${Color_Off}Certificate Configuration based on input...\n"
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Create Certificate is	\"${BYellow}$certificate_create${Color_Off}\"" 
		echo -e "${Color_Off}Certificates creation is being skipped in this install..."
	fi
	outputConfiguration	
	buildFileStructure
}

checkConfigCompatibility(){
	echo -e "${BGreen}Configuration File:${Color_Off} Checking installer configuration file compatibility"
	echo -e "${BGreen}Configuration File:${Color_Off} Configuration file ${BGreen}$1${Color_Off} is a version ${BGreen}${config_fileVersion}${Color_Off} configuration file"
	compatibleConfigFileVersion=0
	case "$config_synkrosVersion" in
		"4.0.10")
			compatibleConfigFileVersion=2.00
			;;
		"4.1.0")
			compatibleConfigFileVersion=2.00
			;;
		*)
			compatibleConfigFileVersion=2.00
			;;
	esac

	if (( $(echo "$compatibleConfigFileVersion > $config_fileVersion" | bc -l) )); then
		echo -e "${BGreen}Configuration File:${Color_Off} Configuration file ${BGreen}$1${Color_Off} is ${BRed}not compatible${Color_Off} with Synkros Version ${BGreen}${config_synkrosVersion}${Color_Off}."
		echo -e "${BGreen}Configuration File:${Color_Off} Synkros Version ${BGreen}${config_synkrosVersion}${Color_Off} requires a configuration file of ${BGreen}${compatibleConfigFileVersion} or higher${Color_Off}."
		exit
	else
		echo -e "${BGreen}Configuration File:${Color_Off} Configuration file ${BGreen}$1${Color_Off} is ${BGreen}compatible${Color_Off} with Synkros Version ${BGreen}${config_synkrosVersion}${Color_Off}."
	fi
}

getInputFromFile(){
	echo -e "${Color_Off}Processing Configuration file ${BGreen}$1${Color_Off}..."
	
	#get config settings
	config_fileVersion=$(awk -F ":" '/configurationVersion:/ {print $2}' $1  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_synkrosVersion=$(awk -F ":" '/synkrosVersion:/ {print $2}' $1  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	config_server_host=$(awk -F ":" '/serverHostnameOrAddess:/ {print $2}' $1  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	config_db_host=$(awk -F ":" '/databaseHostnameOrAddess:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_db_port=$(awk -F ":" '/databasePort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_db_instance=$(awk -F ":" '/databaseInstance:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	config_kweb_apiPort=$(awk -F ":" '/konamiwebAPIPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_kweb_adminPort=$(awk -F ":" '/konamiwebAdminPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_kweb_bridge=$(awk -F ":" '/konamiwebBridge:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_kweb_memory=$(awk -F ":" '/konamiwebMemory:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_kweb_args=$(awk -F ":" '/konamiwebArgs:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	config_rabbitmq_enable=$(awk -F ":" '/rabbitmq:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_rabbitmq_mqPort=$(awk -F ":" '/rabbitmqPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_rabbitmq_adminPort=$(awk -F ":" '/rabbitmqAdminPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	config_ui_monitor_port=$(awk -F ":" '/uiPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_ui_monitor_sslPort=$(awk -F ":" '/uiSSLPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_ui_monitor_synkUIEnabled=$(awk -F ":" '/synkrosUI:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_ui_monitor_synk31Enabled=$(awk -F ":" '/synk31UI:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	config_ui_monitor_helpEnabled=$(awk -F ":" '/synkrosHelp:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	needIWare=$(awk -F ":" '/iwareInstall:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	certificate_create=$(awk -F ":" '/createCertificate:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

	if $certificate_create; then
		certificate_domain=${config_server_host}
		certificate_organizationName=$(awk -F ":" '/certificateOrganizationName:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		certificate_location=$(awk -F ":" '/certificateLocation:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		certificate_state=$(awk -F ":" '/certificateState:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		certificate_country=$(awk -F ":" '/certificateCountry:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		certificate_organizationalUnit=$(awk -F ":" '/certificateOrganizationUnit:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		certificate_email=$(awk -F ":" '/certificateEmail:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		certificate_commonName=$(awk -F ":" '/certificateCommonName:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	fi

	if $needIWare; then
		config_iware_webPort=$(awk -F ":" '/iwareWebPort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		config_iware_cmdPort=$(awk -F ":" '/iwareCommandLinePort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		config_iware_mobilePort=$(awk -F ":" '/iwareMobilePort:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		useDispatch=$(awk -F ":" '/iwareEnableDispatchPlugIn:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		useSynk31=$(awk -F ":" '/iwareEnableSynk31PlugIn:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		useSMS=$(awk -F ":" '/iwareEnableSMSPlugIn:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	fi
	
	if $useSMS ; then
		iware_smsFromNumber=$(awk -F ":" '/iwareSMSFromNumber:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		iware_smsAccountSID=$(awk -F ":" '/iwareSMSAccountSID:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		iware_smsAuthToken=$(awk -F ":" '/iwareSMSAuthorizationToken:/ {print $2}' $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	fi
	
	echo -e "${Color_Off}Processing Configuration file ${BGreen}$1${Color_Off}...${BGreen}Complete${Color_Off}"	
}

outputConfiguration(){
	echo -e "\n${Color_Off}Configuration based on input...\n"
	echo -e "${BGreen}Server Config Details:		${Color_Off} Hostname/address is	\"${BYellow}$config_server_host${Color_Off}\"" 
	echo -e " "	
	echo -e "${BGreen}Installer Config Details:	${Color_Off} Config. Version is	\"${BYellow}$config_fileVersion${Color_Off}\"" 
	echo -e "${BGreen}Installer Config Details:	${Color_Off} Synkros Version is	\"${BYellow}$config_synkrosVersion${Color_Off}\"" 
	echo -e " "
	echo -e "${BGreen}Database Config Details:	${Color_Off} Hostname/address is	\"${BYellow}$config_db_host${Color_Off}\"" 
	echo -e "${BGreen}Database Config Details:	${Color_Off} Port is	 	\"${BYellow}$config_db_port${Color_Off}\"" 
	echo -e "${BGreen}Database Config Details:	${Color_Off} Instance is		\"${BYellow}$config_db_instance${Color_Off}\"" 
	echo -e " "		
	echo -e "${BGreen}Konami Web config Details:	${Color_Off} API Port is		\"${BYellow}$config_kweb_apiPort${Color_Off}\"" 
	echo -e "${BGreen}Konami Web config Details:	${Color_Off} Admin Port is		\"${BYellow}$config_kweb_adminPort${Color_Off}\"" 
	echo -e "${BGreen}Konami Web config Details:	${Color_Off} Bridge is		\"${BYellow}$config_kweb_bridge${Color_Off}\"" 
	echo -e "${BGreen}Konami Web config Details:	${Color_Off} Memory is		\"${BYellow}$config_kweb_memory${Color_Off}\"" 
	echo -e "${BGreen}Konami Web config Details:	${Color_Off} Args is		\"${BYellow}$config_kweb_args${Color_Off}\"" 
	echo -e " "	
	echo -e "${BGreen}Rabbit MQ config Details:	${Color_Off} Rabbit MQ is		\"${BYellow}$config_rabbitmq_enable${Color_Off}\"" 
	if $config_rabbitmq_enable; then
		echo -e "${BGreen}Rabbit MQ config Details:	${Color_Off} Service Port is	\"${BYellow}$config_rabbitmq_mqPort${Color_Off}\"" 
		echo -e "${BGreen}Rabbit MQ config Details:	${Color_Off} Admin Port is		\"${BYellow}$config_rabbitmq_adminPort${Color_Off}\"" 
	fi
	echo -e " "		
	echo -e "${BGreen}UI Monitor config Details:	${Color_Off} UI Port is		\"${BYellow}$config_ui_monitor_port${Color_Off}\"" 
	echo -e "${BGreen}UI Monitor config Details:	${Color_Off} UI SSL Port is		\"${BYellow}$config_ui_monitor_sslPort${Color_Off}\"" 
	echo -e "${BGreen}UI Monitor config Details:	${Color_Off} Synk UI is		\"${BYellow}$config_ui_monitor_synkUIEnabled${Color_Off}\"" 
	echo -e "${BGreen}UI Monitor config Details:	${Color_Off} Synk 31 is		\"${BYellow}$config_ui_monitor_synk31Enabled${Color_Off}\"" 
	echo -e "${BGreen}UI Monitor config Details:	${Color_Off} Help is		\"${BYellow}$config_ui_monitor_helpEnabled${Color_Off}\"" 
	echo -e " "	

	echo -e "${BGreen}IWare config Details:		${Color_Off} IWare Install is	\"${BYellow}$needIWare${Color_Off}\"" 
	if $needIWare; then
		echo -e "${BGreen}IWare config Details:		${Color_Off} Web Port is		\"${BYellow}$config_iware_webPort${Color_Off}\"" 
		echo -e "${BGreen}IWare config Details:		${Color_Off} Command Line Port is	\"${BYellow}$config_iware_cmdPort${Color_Off}\""  
		echo -e "${BGreen}IWare config Details:		${Color_Off} Mobile Port is		\"${BYellow}$config_iware_mobilePort${Color_Off}\"" 
		echo -e "${BGreen}IWare config Details:		${Color_Off} Dispatch enabled is	\"${BYellow}$useDispatch${Color_Off}\""
		echo -e "${BGreen}IWare config Details:		${Color_Off} Synk31 enabled is 	\"${BYellow}$useSynk31${Color_Off}\""
		echo -e "${BGreen}IWare config Details:		${Color_Off} SMS enabled is		\"${BYellow}$useSMS${Color_Off}\""
		
		if $useSMS; then
			echo -e "${BGreen}IWare config Details:		${Color_Off} SMS From Number is	\"${BYellow}$iware_smsFromNumber${Color_Off}\"" 
			echo -e "${BGreen}IWare config Details:		${Color_Off} SMS Account SID is	\"${BYellow}$iware_smsAccountSID${Color_Off}\"" 
			echo -e "${BGreen}IWare config Details:		${Color_Off} SMS Auth. Token is	\"${BYellow}$iware_smsAuthToken${Color_Off}\"" 
		fi	
		echo -e " "	
	fi
	echo -e " "
}

outputCertificateConfiguration(){
	echo -e "\n${Color_Off}Certificate Configuration based on input...\n"
	echo -e "${BGreen}Certificate config Details:		${Color_Off} Create Certificate is	\"${BYellow}$certificate_create${Color_Off}\"" 
	if $certificate_create; then
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Domain is		\"${BYellow}$certificate_domain${Color_Off}\"" 
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Org. Name is		\"${BYellow}$certificate_organizationName${Color_Off}\""
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Location is		\"${BYellow}$certificate_location${Color_Off}\""
		echo -e "${BGreen}Certificate config Details:		${Color_Off} State is		\"${BYellow}$certificate_state${Color_Off}\""
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Country is		\"${BYellow}$certificate_country${Color_Off}\""
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Org. Unit is		\"${BYellow}$certificate_organizationalUnit${Color_Off}\""
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Email is		\"${BYellow}$certificate_email${Color_Off}\""
		echo -e "${BGreen}Certificate config Details:		${Color_Off} Common Name is		\"${BYellow}$certificate_commonName${Color_Off}\""
	fi
	echo -e " "
}

runDockerCompose(){
	echo -e "\n${Color_Off}Running Docker Compose..."
	cd KonamiGaming
	sudo /usr/local/bin/docker-compose up -d --remove-orphans
	echo -e "${Color_Off}Running Docker Compose...${BGreen}Complete" 
}

buildFileStructure(){
	upperCaseDatabaseInstance=${config_db_instance^^}

	#create directory variables
	installDirectory="$PWD/KonamiGaming/$upperCaseDatabaseInstance"
	konamiWebConfigDirectory="$installDirectory/KonamiWeb/Config"
	konamiWebLogsDirectory="$installDirectory/KonamiWeb/Logs"
	konamiWebBinDirectory="$installDirectory/KonamiWeb/Bin"
	konamiWebLogsDBObjectsDirectory="$konamiWebLogsDirectory/DBObjects"
	konamiWebCertsDirectory="$PWD/KonamiGaming/certs"
	konamiWebSSLDirectory="$PWD/KonamiGaming/ssl"
	konamiWebStoresDirectory="$PWD/KonamiGaming/stores"
	konamiWebSiteDirectory="$konamiWebConfigDirectory/site"
	iWareConfigDirectory="$installDirectory/IWare/Config"
	iWareLogsDirectory="$installDirectory/IWare/Logs"
	iWareBinDirectory="$installDirectory/IWare/Bin"
	rabbitMQLogsDirectory="$installDirectory/RabbitMQ/Logs"
	htmlDirectory="$installDirectory/html"
	synkrosUIDirectory="$htmlDirectory/Synkros-UI"
	synkrosHelpDirectory="$htmlDirectory/Help"
	synk31Directory="$htmlDirectory/Synk31"
	readMeDirectory="$htmlDirectory/ReadMe"
	synkUIConfigDirectory="$installDirectory/SynkUI/Config"
	synkUILogsDirectory="$installDirectory/SynkUI/Logs"

	echo -e "${Color_Off}Creating directories..."
	
	echo -e "   ${Color_Off}Created ${BGreen}$installDirectory"
	mkdir -p "$installDirectory"
	
	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebCertsDirectory"
	mkdir -p "$konamiWebCertsDirectory"
	
	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebSSLDirectory"
	mkdir -p "$konamiWebSSLDirectory"
	
	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebStoresDirectory"
	mkdir -p "$konamiWebStoresDirectory"

	if $needIWare; then
		echo -e "   ${Color_Off}Created ${BGreen}$iWareConfigDirectory"
		mkdir -p "$iWareConfigDirectory"
	
		echo -e "   ${Color_Off}Created ${BGreen}$iWareLogsDirectory"
		mkdir -p "$iWareLogsDirectory"

		echo -e "   ${Color_Off}Created ${BGreen}$iWareBinDirectory"
		mkdir -p "$iWareBinDirectory"
	fi

	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebConfigDirectory"
	mkdir -p "$konamiWebConfigDirectory"
	
	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebBinDirectory"
	mkdir -p "$konamiWebBinDirectory"
	
	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebLogsDirectory"
	mkdir -p "$konamiWebLogsDirectory"

	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebLogsDBObjectsDirectory"
	mkdir -p "$konamiWebLogsDBObjectsDirectory"

	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebSiteDirectory"
	mkdir -p "$konamiWebSiteDirectory"

	if $config_rabbitmq_enable; then
		echo -e "   ${Color_Off}Created ${BGreen}$rabbitMQLogsDirectory"
		mkdir -p "$rabbitMQLogsDirectory"
	fi

	echo -e "   ${Color_Off}Created ${BGreen}$htmlDirectory"
	mkdir -p "$htmlDirectory"

	if $config_ui_monitor_synkUIEnabled; then
		echo -e "   ${Color_Off}Created ${BGreen}$synkrosUIDirectory"
		mkdir -p "$synkrosUIDirectory"
	fi

	if $config_ui_monitor_synk31Enabled; then
		echo -e "   ${Color_Off}Created ${BGreen}$synk31Directory"
		mkdir -p "$synk31Directory"
	fi

	if $config_ui_monitor_helpEnabled; then
		echo -e "   ${Color_Off}Created ${BGreen}$synkrosHelpDirectory"
		mkdir -p "$synkrosHelpDirectory"
	fi

	echo -e "   ${Color_Off}Created ${BGreen}$readMeDirectory"
	mkdir -p "$readMeDirectory"

	echo -e "   ${Color_Off}Created ${BGreen}$synkUIConfigDirectory"
	mkdir -p "$synkUIConfigDirectory"

	echo -e "   ${Color_Off}Created ${BGreen}$synkUILogsDirectory"
	mkdir -p "$synkUILogsDirectory"
					
	echo -e "${Color_Off}Creating directories...${BGreen}Complete"

	echo -e "\n${Color_Off}Creating Configuration Files..."
	createSiteConfig
	createMonitorConfig
	createSSLConfig

	#Create IWare Config Files
	if $needIWare; then
		createConnectionsConfig
		createIWareConfig	
	fi

	#echo -e "${Color_Off}Creating Docker Compose File..."
	createDockerComposeFile
	#echo -e "${Color_Off}Creating Docker Compose File...${BGreen}Complete"
	
	#echo -e "${Color_Off}Creating ReadMe File..."
	createHTMLReadMeFile
	#echo -e "${Color_Off}Creating ReadMe File...${BGreen}Complete"
	echo -e "${Color_Off}Creating Configuration Files...${BGreen}Complete"
}

createConnectionsConfig(){
	# Base 
	echo "konami.middleware.scheduler.SchedulerPlugin" > "$iWareConfigDirectory/Connection.PlugIns"
	echo "konami.middleware.plugins.sms.EmailServicePlugIn" >> "$iWareConfigDirectory/Connection.PlugIns"

	#As Needed
	if $useDispatch; then
		echo "konami.middleware.plugins.dispatch.DispatchPlugIn" >> "$iWareConfigDirectory/Connection.PlugIns"
	else 
		echo "#konami.middleware.plugins.dispatch.DispatchPlugIn" >> "$iWareConfigDirectory/Connection.PlugIns"
	fi

	if $useSynk31; then
		echo "konami.middleware.synk31.Synk31Plugin" >> "$iWareConfigDirectory/Connection.PlugIns"	
	else 
		echo "#konami.middleware.synk31.Synk31Plugin" >> "$iWareConfigDirectory/Connection.PlugIns"
	fi

	if $useSMS; then
		echo "konami.middleware.plugins.sms.SMSServicePlugIn" >> "$iWareConfigDirectory/Connection.PlugIns"	
	else 
		echo "#konami.middleware.plugins.sms.SMSServicePlugIn" >> "$iWareConfigDirectory/Connection.PlugIns"
	fi
	
	# Obsolete
	echo "#konami.middleware.connections.messaging.MQListenerPlugIn" >> "$iWareConfigDirectory/Connection.PlugIns"
	echo "#konami.middleware.processor.ProcessHandler" >> "$iWareConfigDirectory/Connection.PlugIns"
	echo "#konami.middleware.queue.WorkQueue" >> "$iWareConfigDirectory/Connection.PlugIns"
	
	echo -e "   ${Color_Off}Created ${BGreen}$iWareConfigDirectory/Connection.PlugIns"
}

createSSLConfig(){
	echo "Create ssl.conf"
}

createIWareConfig(){
	echo "konami.commandinterface.webserver.port=8001" > "$iWareConfigDirectory/iWare.prop"
	echo "konami.commandinterface.cmdline.port=8002" >> "$iWareConfigDirectory/iWare.prop"
	echo "ems.dbobjects.connections=4" >> "$iWareConfigDirectory/iWare.prop"
	echo "QueueThreshold=25" >> "$iWareConfigDirectory/iWare.prop"
	echo "MaxProcessors=3" >> "$iWareConfigDirectory/iWare.prop"

	echo "ems.db.server=$config_db_host" >> "$iWareConfigDirectory/iWare.prop"
	echo "ems.db.port=$config_db_port" >> "$iWareConfigDirectory/iWare.prop"
	echo "ems.db.instance=$config_db_instance" >> "$iWareConfigDirectory/iWare.prop"
	echo "kcms.scheduler.purge=1" >> "$iWareConfigDirectory/iWare.prop"

	echo "iware.systemmessage.routing.key=synkros-mw.mcast" >> "$iWareConfigDirectory/iWare.prop"
	echo "ems.iop.type=address" >> "$iWareConfigDirectory/iWare.prop"

	if $useSMS; then
		echo "#konami.sms.provider=TwilioSMSService" >> "$iWareConfigDirectory/iWare.prop"
		echo "#com.twilio.from.number=" >> "$iWareConfigDirectory/iWare.prop"
		echo "#com.twilio.account.sid=" >> "$iWareConfigDirectory/iWare.prop"
		echo "#com.twilio.auth.token=" >> "$iWareConfigDirectory/iWare.prop"
	else
		echo "konami.sms.provider=TwilioSMSService" >> "$iWareConfigDirectory/iWare.prop"
		echo "com.twilio.from.number=$iware_smsFromNumber" >> "$iWareConfigDirectory/iWare.prop"
		echo "com.twilio.account.sid=$iware_smsAccountSID" >> "$iWareConfigDirectory/iWare.prop"
		echo "com.twilio.auth.token=$iware_smsAuthToken" >> "$iWareConfigDirectory/iWare.prop"
	fi
	echo -e "   ${Color_Off}Created ${BGreen}$iWareConfigDirectory/iWare.prop"
}

createSiteConfig(){
	upperCaseDatabaseInstance=${config_db_instance^^}	
	echo "database_tns: (DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = $config_db_host)(PORT = $config_db_port)) ) (CONNECT_DATA = (SERVICE_NAME = $config_db_instance.$config_db_host) ) )" > "$konamiWebSiteDirectory/siteConfig.yml"
	echo "site: KWEB$upperCaseDatabaseInstance" >> "$konamiWebSiteDirectory/siteConfig.yml"
	echo "host: KWEB$upperCaseDatabaseInstance">> "$konamiWebSiteDirectory/siteConfig.yml"
	echo "apiPort: 8443">> "$konamiWebSiteDirectory/siteConfig.yml"
	echo "adminPort: 8444">> "$konamiWebSiteDirectory/siteConfig.yml"
	echo "useAQMQBridge: $config_kweb_bridge">> "$konamiWebSiteDirectory/siteConfig.yml"
	echo "memoryAllocation: $config_kweb_memory">> "$konamiWebSiteDirectory/siteConfig.yml"
	echo "additionalRunTimeArgs: $config_kweb_args">> "$konamiWebSiteDirectory/siteConfig.yml"
	echo -e "   ${Color_Off}Created ${BGreen}$konamiWebSiteDirectory/siteConfig.yml"
}

createMonitorConfig(){
	upperCaseDatabaseInstance=${config_db_instance^^}
	
	echo "#Monitor Config File" > "$synkUIConfigDirectory/monitor.config"
	echo "debugLogging: true" >> "$synkUIConfigDirectory/monitor.config"

	echo "#Database Configuration" >> "$synkUIConfigDirectory/monitor.config"
	echo "databaseTNS: (DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = $config_db_host)(PORT = $config_db_port)) ) (CONNECT_DATA = (SERVICE_NAME = $config_db_instance.$config_db_host) ) )" >> "$synkUIConfigDirectory/monitor.config"

	echo "#SynkUI Configuration" >> "$synkUIConfigDirectory/monitor.config"
	if $config_ui_monitor_synkUIEnabled; then
		echo "synkuiEnabled: true" >> "$synkUIConfigDirectory/monitor.config" 
	else
		echo "synkuiEnabled: false" >> "$synkUIConfigDirectory/monitor.config" 
	fi  
	echo "synkuiHost: $config_server_host"  >> "$synkUIConfigDirectory/monitor.config"
	echo "synkuiPort: $config_kweb_apiPort" >> "$synkUIConfigDirectory/monitor.config"
	echo "synkuiOutFolder: /var/www/localhost/htdocs/Synkros-UI" >> "$synkUIConfigDirectory/monitor.config"

	echo "#Synk31 Configuration" >> "$synkUIConfigDirectory/monitor.config"
	if $config_ui_monitor_synk31Enabled; then
		echo "synk31Enabled: true" >> "$synkUIConfigDirectory/monitor.config" 
	else
		echo "synk31Enabled: false" >> "$synkUIConfigDirectory/monitor.config" 
	fi  
	echo "synk31Host: $config_server_host"  >> "$synkUIConfigDirectory/monitor.config" 
	echo "synk31Port: $config_kweb_apiPort"   >> "$synkUIConfigDirectory/monitor.config"
	echo "synk31OutFolder: /var/www/localhost/htdocs/Synk31" >> "$synkUIConfigDirectory/monitor.config"

	echo "# help docs" >> "$synkUIConfigDirectory/monitor.config"
	if $config_ui_monitor_helpEnabled; then
		echo "helpDocsEnabled: true" >> "$synkUIConfigDirectory/monitor.config" 
	else
		echo "helpDocsEnabled: false" >> "$synkUIConfigDirectory/monitor.config" 
	fi 
	echo "helpDocsOutFolder: /var/www/localhost/htdocs/Help" >> "$synkUIConfigDirectory/monitor.config"
	echo -e "   ${Color_Off}Created ${BGreen}$synkUIConfigDirectory/monitor.config"

}

createDockerComposeFile(){
	kWebDirectory="$PWD/KonamiGaming"
	lowerCaseDatabaseInstance=${config_db_instance,,}
	upperCaseDatabaseInstance=${config_db_instance^^}

	if ! $appendToCompose; then
		echo "version: \"3"\" > "$kWebDirectory/docker-compose.yml"
		echo "services:" >> "$kWebDirectory/docker-compose.yml"
	fi
	if $config_rabbitmq_enable; then
		echo "  rabbitmq_${lowerCaseDatabaseInstance}:" >> "$kWebDirectory/docker-compose.yml"
		echo "    image: feqa.kgisystems.com:5000/konamigaming/rabbitmq:v${config_synkrosVersion}" >> "$kWebDirectory/docker-compose.yml"
		echo "    hostname: ${lowerCaseDatabaseInstance}rabbit" >> "$kWebDirectory/docker-compose.yml"
		echo "    volumes:" >> "$kWebDirectory/docker-compose.yml"
		echo "      - \"$rabbitMQLogsDirectory:/var/log/rabbitmq/log\"" >> "$kWebDirectory/docker-compose.yml"
		echo "    ports:" >> "$kWebDirectory/docker-compose.yml"
		echo "      - $config_rabbitmq_mqPort:5672"  >> "$kWebDirectory/docker-compose.yml"
		echo "      - $config_rabbitmq_adminPort:15672"  >> "$kWebDirectory/docker-compose.yml"
		echo "    container_name: RABBITMQ${upperCaseDatabaseInstance}" >> "$kWebDirectory/docker-compose.yml"
	fi
	echo "  httpd_${lowerCaseDatabaseInstance}:" >> "$kWebDirectory/docker-compose.yml"
	echo "    image: feqa.kgisystems.com:5000/konamigaming/httpd:v${config_synkrosVersion}" >> "$kWebDirectory/docker-compose.yml"
	echo "    volumes:" >> "$kWebDirectory/docker-compose.yml"
	if $config_ui_monitor_synkUIEnabled; then
		echo "      - \"$synkrosUIDirectory:/var/www/html/$lowerCaseDatabaseInstance/Synkros-UI\"" >> "$kWebDirectory/docker-compose.yml"
	fi
	if $config_ui_monitor_synk31Enabled; then
		echo "      - \"$synk31Directory:/var/www/html/$lowerCaseDatabaseInstance/Synk31\"" >> "$kWebDirectory/docker-compose.yml"
	fi
	if $config_ui_monitor_helpEnabled; then	
		echo "      - \"$synkrosHelpDirectory:/var/www/html/$lowerCaseDatabaseInstance/Help\"" >> "$kWebDirectory/docker-compose.yml"
	fi
	echo "      - \"$readMeDirectory:/var/www/html/$lowerCaseDatabaseInstance/ReadMe\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$synkUILogsDirectory:/var/www/html/$lowerCaseDatabaseInstance/Monitor\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebSSLDirectory/ssl.conf:/etc/httpd/conf.d/ssl.conf\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebCertsDirectory/fedev.key:/etc/pki/tls/private/fedev.key\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebCertsDirectory/fedev-chain.pem:/etc/pki/tls/certs/fedev-chain.pem\"" >> "$kWebDirectory/docker-compose.yml"
	#echo "      - \"$konamiWebCertsDirectory/${certificate_commonName}.pem:/etc/pki/tls/certs/${certificate_commonName}.pem\"" >> "$kWebDirectory/docker-compose.yml"
	#echo "      - \"$konamiWebCertsDirectory/${certificate_commonName}.key:/etc/pki/tls/private/${certificate_commonName}.key\"" >> "$kWebDirectory/docker-compose.yml"
	#echo "      - \"$konamiWebCertsDirectory/${certificate_commonName}-chain.pem:/etc/pki/tls/certs/${certificate_commonName}-chain.pem\"" >> "$kWebDirectory/docker-compose.yml"
	echo "    ports:" >> "$kWebDirectory/docker-compose.yml"
	echo "      - $config_ui_monitor_port:80" >> "$kWebDirectory/docker-compose.yml"
	echo "      - $config_ui_monitor_sslPort:443" >> "$kWebDirectory/docker-compose.yml"
	echo "    depends_on:" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"synkuimonitor_${lowerCaseDatabaseInstance}\"" >> "$kWebDirectory/docker-compose.yml"
	echo "    restart: always" >> "$kWebDirectory/docker-compose.yml"
	echo "    container_name: SYNKUI${upperCaseDatabaseInstance}"  >> "$kWebDirectory/docker-compose.yml"
	echo "  synkuimonitor_${lowerCaseDatabaseInstance}:"  >> "$kWebDirectory/docker-compose.yml"
	echo "    image: feqa.kgisystems.com:5000/konamigaming/synkuimonitor:v${config_synkrosVersion}" >> "$kWebDirectory/docker-compose.yml"
	echo "    volumes:"  >> "$kWebDirectory/docker-compose.yml"
	echo "      - "$synkUIConfigDirectory/monitor.config:/usr/SynkUI/monitor.config"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - "$synkUILogsDirectory:/usr/SynkUI/logs"" >> "$kWebDirectory/docker-compose.yml"
	if $config_ui_monitor_synkUIEnabled; then
		echo "      - "$synkrosUIDirectory:/var/www/localhost/htdocs/Synkros-UI"" >> "$kWebDirectory/docker-compose.yml"
	fi
	if $config_ui_monitor_synk31Enabled; then
		echo "      - "$synk31Directory:/var/www/localhost/htdocs/Synk31"" >> "$kWebDirectory/docker-compose.yml"
	fi
	if $config_ui_monitor_helpEnabled; then	
		echo "      - "$synkrosHelpDirectory:/var/www/localhost/htdocs/Help"" >> "$kWebDirectory/docker-compose.yml"
	fi
	echo "    restart: always" >> "$kWebDirectory/docker-compose.yml"
	echo "    container_name: SYNKUIMONITOR${upperCaseDatabaseInstance}" >> "$kWebDirectory/docker-compose.yml"
	echo "  konamiweb_${lowerCaseDatabaseInstance}:" >> "$kWebDirectory/docker-compose.yml"
	echo "    image: feqa.kgisystems.com:5000/konamigaming/konamiweb:v${config_synkrosVersion}" >> "$kWebDirectory/docker-compose.yml"
	echo "    ports:"  >> "$kWebDirectory/docker-compose.yml"
	echo "      - $config_kweb_apiPort:8443" >> "$kWebDirectory/docker-compose.yml"
	echo "      - $config_kweb_adminPort:8444" >> "$kWebDirectory/docker-compose.yml"
	echo "    volumes:"  >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebSiteDirectory:/home/dev/KonamiWeb/config/site\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebLogsDirectory:/home/dev/KonamiWeb/logs\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebBinDirectory:/home/dev/KonamiWeb/libs/bin\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebCertsDirectory:/home/dev/KonamiWeb/config/certs\"" >> "$kWebDirectory/docker-compose.yml"
	echo "      - \"$konamiWebStoresDirectory:/home/dev/KonamiWeb/config/stores\"" >> "$kWebDirectory/docker-compose.yml"
	echo "    depends_on:" >> "$kWebDirectory/docker-compose.yml"
	if $config_rabbitmq_enable; then
		echo "      - \"rabbitmq_${lowerCaseDatabaseInstance}\"" >> "$kWebDirectory/docker-compose.yml"
	fi
	echo "      - \"httpd_${lowerCaseDatabaseInstance}\"" >> "$kWebDirectory/docker-compose.yml"
	echo "    restart: always" >> "$kWebDirectory/docker-compose.yml"
	echo "    container_name: KWEB${upperCaseDatabaseInstance}" >> "$kWebDirectory/docker-compose.yml"
	
	if $needIWare; then
		echo "  iware_${lowerCaseDatabaseInstance}:" >> "$kWebDirectory/docker-compose.yml"
		echo "    image: feqa.kgisystems.com:5000/konamigaming/iware:v${config_synkrosVersion}" >> "$kWebDirectory/docker-compose.yml"
		echo "    ports:"  >> "$kWebDirectory/docker-compose.yml"
		echo "      - $config_iware_webPort:8001" >> "$kWebDirectory/docker-compose.yml"
		echo "      - $config_iware_cmdPort:8002" >> "$kWebDirectory/docker-compose.yml"
		echo "      - $config_iware_mobilePort:7002" >> "$kWebDirectory/docker-compose.yml"
		echo "    volumes:"  >> "$kWebDirectory/docker-compose.yml"
		echo "      - \"$iWareConfigDirectory/iWare.prop:/home/dev/IWare/conf/iWare.prop\"" >> "$kWebDirectory/docker-compose.yml"
		echo "      - \"$iWareConfigDirectory/Connection.PlugIns:/home/dev/IWare/conf/Connection.PlugIns\"" >> "$kWebDirectory/docker-compose.yml"
		echo "      - \"$iWareLogsDirectory:/home/dev/IWare/log\"" >> "$kWebDirectory/docker-compose.yml"
		echo "      - \"$iWareBinDirectory:/home/dev/IWare/libs/bin\"" >> "$kWebDirectory/docker-compose.yml"
		echo "    depends_on:" >> "$kWebDirectory/docker-compose.yml"
		if $config_rabbitmq_enable; then
			echo "      - \"rabbitmq_${lowerCaseDatabaseInstance}\"" >> "$kWebDirectory/docker-compose.yml"
		fi
		echo "    restart: always" >> "$kWebDirectory/docker-compose.yml"
		echo "    container_name: IWARE${upperCaseDatabaseInstance}" >> "$kWebDirectory/docker-compose.yml"
	fi
	#echo "networks:" >> "$kWebDirectory/docker-compose.yml"
	#echo "  default:" >> "$kWebDirectory/docker-compose.yml"
	#echo "    driver: bridge" >> "$kWebDirectory/docker-compose.yml"
	#echo "    ipam:" >> "$kWebDirectory/docker-compose.yml"
	#echo "      config:" 	>> "$kWebDirectory/docker-compose.yml"
	#echo "        - subnet: 172.16.57.0/24" >> "$kWebDirectory/docker-compose.yml"

	if $appendToCompose; then
		echo -e "   ${Color_Off}Appended ${BGreen}$kWebDirectory/docker-compose.yml"
	else
		echo -e "   ${Color_Off}Created ${BGreen}$kWebDirectory/docker-compose.yml"
		appendToCompose=true
	fi
}

createDaemonJson(){
	echo -e "${Color_Off}Creating Docker Daemon Json File..."
	sudo mkdir -p /etc/docker
	sudo touch "/etc/docker/daemon.json"
	sudo bash -c 'echo -e "{\n  \"insecure-registries\" : [\"feqa.kgisystems.com:5000\"]\n}" > "/etc/docker/daemon.json"'
	echo -e "${Color_Off}Creating Docker Daemon Json File...${BGreen}Complete"
}

checkAndInstallDocker(){ 
	if isDockerInstalled; then
		if ask "${Color_Off}Would you like to reinstall Docker? (will Require SUDO Access)" N; then
			uninstallDocker
			installDocker
			checkDockerInstallationSuccess
		fi
	elif ask "${Color_Off}Would you like to install Docker (will Require SUDO Access)?" N; then
		installDocker
		checkDockerInstallationSuccess
	else 
		echo -e "${Color_Off}Installing Docker...${BYellow}Skipped!"
		checkDockerInstallationSuccess
	fi
}

createCertificate(){
	certificateDirectory="$PWD/KonamiGaming/certs"
	storesDirectory="$PWD/KonamiGaming/stores"
	caFound=false

	#Create Directories
	echo -e  "\n${Color_Off}Creating certificates directory..." 
	mkdir -p "$certificateDirectory"
	echo -e  "${Color_Off}Created ${BGreen}$certificateDirectory${Color_Off}" 

	echo -e  "\n${Color_Off}Creating keystores directory..." 
	mkdir -p "$storesDirectory"
	echo -e  "${Color_Off}Created ${BGreen}$storesDirectory${Color_Off}"

	#move ca files if found
	for FILE in *; do 
		if echo $FILE | grep -iqF ca.; then
			echo -e  "${Color_Off}Copying ${BGreen}$FILE${Color_Off} to ${certificateDirectory}" 
    			cp $FILE ${certificateDirectory}/$FILE
			caFound=true
		fi
	done

	if ! ${caFound}; then
		createCACertificate
	fi

	echo -e  "\n${Color_Off}Creating Subject String..." 
	certificate_subject="/C=${certificate_country}/ST=${certificate_state}/L=${certificate_location}/O=${certificate_organizationName}/OU=${certificate_organizationalUnit}/CN=${certificate_domain}/emailAddress=${certificate_email}"
	echo -e  "${Color_Off}Subject String: ${BGreen}${certificate_subject}${Color_Off}" 

	echo -e  "\n${Color_Off}Removing existing certificates ${BGreen}${certificate_commonName}.req ${certificate_commonName}.key ${certificate_commonName}.cer${Color_Off} from ${BGreen}${certificateDirectory}${Color_Off}..."
	rm ${certificateDirectory}/${certificate_commonName}.req ${certificateDirectory}/${certificate_commonName}.key ${certificateDirectory}/${certificate_commonName}.cer
	echo -e  "${Color_Off}Completed removing existing certificates" 

	echo -e  "\n${Color_Off}Creating Private Key..."
	openssl genrsa -out ${certificateDirectory}/${certificate_commonName}.key 4096
	if [ -f "${certificateDirectory}/${certificate_commonName}.key" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/${certificate_commonName}.key${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/${certificate_commonName}.key${Color_Off}"
		exit
	fi

	echo -e  "\n${Color_Off}Generating SAN String..."
	certificate_san="\n[SAN]"
	certificate_san="${certificate_san}\nsubjectAltName = DNS:${certificate_domain}"
	certificate_san="${certificate_san}\nbasicConstraints = CA:FALSE"
	certificate_san="${certificate_san}\nkeyUsage = nonRepudiation, digitalSignature, keyEncipherment"
	certificate_san="${certificate_san}\nextendedKeyUsage = serverAuth,clientAuth"
	certificate_san="${certificate_san}\nsubjectKeyIdentifier = hash"
	echo -e  "${Color_Off}SAN String: ${BGreen}${certificate_san}${Color_Off}"

	echo -e  "\n${Color_Off}Generating Open SSL New Request..."
	openssl req -new -sha256 -subj "${certificate_subject}" -key ${certificateDirectory}/${certificate_commonName}.key -out ${certificateDirectory}/${certificate_commonName}.req -reqexts SAN -config <(cat /etc/pki/tls/openssl.cnf <(printf "${certificate_san}"))
	if [ -f "${certificateDirectory}/${certificate_commonName}.req" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/${certificate_commonName}.req${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/${certificate_commonName}.req${Color_Off}"
		exit
	fi

	echo -e  "\n${Color_Off}Generating SANs extension file..."
	printf "${certificate_san}" > "${certificateDirectory}/${certificate_commonName}.ext"
	if [ -f "${certificateDirectory}/${certificate_commonName}.ext" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/${certificate_commonName}.ext${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/${certificate_commonName}.ext${Color_Off}"
		exit
	fi

	echo -e  "\n${Color_Off}Run Request for certificate..."
	openssl x509 -req -in ${certificateDirectory}/${certificate_commonName}.req -CA ${certificateDirectory}/ca.cer -CAkey ${certificateDirectory}/ca.key -days 825 -passin pass:${certificate_ca_key_pass} -outform PEM -out ${certificateDirectory}/${certificate_commonName}.cer -extfile ${certificateDirectory}/${certificate_commonName}.ext -extensions SAN	
	if [ -f "${certificateDirectory}/${certificate_commonName}.cer" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/${certificate_commonName}.cer${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/${certificate_commonName}.cer${Color_Off}"
		exit
	fi

	echo -e  "\n${Color_Off}Removing ${certificate_commonName}.ext file..."
	rm ${certificateDirectory}/${certificate_commonName}.ext
	echo -e  "${Color_Off}Completed removing ${BGreen}${certificateDirectory}/${certificate_commonName}.ext${Color_Off}"

	echo -e  "\n${Color_Off}Exporting all certificates in the signing chain into a single file ${BGreen}${certificate_commonName}-chain.cer${Color_Off}..."
	cat ${certificateDirectory}/${certificate_commonName}.cer > ${certificateDirectory}/${certificate_commonName}-chain.cer
	cat ${certificateDirectory}/ca.cer >> ${certificateDirectory}/${certificate_commonName}-chain.cer
	echo -e  "\n${Color_Off}Certificates added to signing chain file ${BGreen}${certificateDirectory}/${certificate_commonName}-chain.cer${Color_Off}..."

	echo -e  "\n${Color_Off}Generating PKCS12 file for server ${BGreen}${certificate_commonName}.p12${Color_Off}..."
	openssl pkcs12 -export -inkey ${certificateDirectory}/${certificate_commonName}.key -in ${certificateDirectory}/${certificate_commonName}-chain.cer -out ${certificateDirectory}/${certificate_commonName}.p12 -passout pass:${certificate_pkcs12_export_pass}
	if [ -f "${certificateDirectory}/${certificate_commonName}.p12" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/${certificate_commonName}.p12${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/${certificate_commonName}.p12${Color_Off}"
		exit
	fi

	echo -e  "\n${Color_Off}Import the Server PKCS12 into the keystore ${BGreen}keystore,jks${Color_Off}..."
	keytool -importkeystore -trustcacerts -srcstorepass ${certificate_pkcs12_export_pass} -deststorepass ${certificate_keystore_pass} -srckeystore ${certificateDirectory}/${certificate_commonName}.p12 -srcstoretype PKCS12 -keystore ${storesDirectory}/keystore.jks -noprompt
	echo -e  "\n${Color_Off}PKCS12 file added to keystore ${BGreen}${storesDirectory}/keystore.jks${Color_Off}..."

	echo -e  "\n${Color_Off}Import the CA certificate into the keystore ${BGreen}keystore,jks${Color_Off}..."
	keytool -import -alias "${certificate_organizationName} CA" -keypass ${certificate_ca_key_pass} -storepass ${certificate_keystore_pass} -trustcacerts -file ${certificateDirectory}/ca.cer -keystore ${storesDirectory}/keystore.jks -noprompt
	echo -e  "\n${Color_Off}CA certificate added to keystore ${BGreen}${storesDirectory}/keystore.jks${Color_Off}..."

	echo -e  "\n${Color_Off}Contents of keystore after adding certificates..."
	keytool -list -v -keystore ${storesDirectory}/keystore.jks -storepass ${certificate_keystore_pass}

	echo -e  "\n${Color_Off}Certificate creation complete\n" 
	alreadyCreatedCertificate=true
}


createCACertificate(){
	echo -e  "\n${Color_Off}Creating Certificate Authority SRL File with ${rNumber}..."
	#((RND=RANDOM<<15|RANDOM)) ; echo ${RND: -8} > ${certificateDirectory}/ca.srl
	echo "10000000" > ${certificateDirectory}/ca.srl
	if [ -f "${certificateDirectory}/ca.srl" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/ca.srl${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/ca.srl${Color_Off}"
		exit
	fi

	echo -e  "\n${Color_Off}Creating Subject String..." 
	certificate_subject="/C=${certificate_country}/ST=${certificate_state}/L=${certificate_location}/O=${certificate_organizationName}/OU=${certificate_organizationalUnit}/CN=${certificate_organizationName} CA/emailAddress=${certificate_email}"
	echo -e  "${Color_Off}Subject String: ${BGreen}${certificate_subject}${Color_Off}" 

	echo -e  "\n${Color_Off}Creating Certificate Authority Key and Certificate File..."
	openssl req -subj "${certificate_subject}" -newkey rsa:4096 -passout pass:${certificate_ca_key_pass} -keyform PEM -keyout ${certificateDirectory}/ca.key -x509 -days 3650 -outform PEM -out ${certificateDirectory}/ca.cer
	if [ -f "${certificateDirectory}/ca.key" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/ca.key${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/ca.key${Color_Off}"
		exit
	fi
	if [ -f "${certificateDirectory}/ca.cer" ]; then
		echo -e  "${Color_Off}Created ${BGreen}${certificateDirectory}/ca.cer${Color_Off}"
    	else
		echo -e  "${BRed}Failed to created ${BGreen}${certificateDirectory}/ca.cer${Color_Off}"
		exit
	fi
	echo -e  "\n${Color_Off}Certificate Authority created..." 
}


isDockerInstalled(){
	echo -ne "${Color_Off}Checking if Docker is installed..."
	if type -p docker; then
    		echo -e "${BGreen}Docker is installed"
			true
	else
    		echo -e "${BRed}Docker is not installed"
			false
	fi
}

installDocker(){
	echo -e "${Color_Off}Installing Docker...${BGreen}Started"
	sudo yum check-update
	sudo yum -y install -y yum-utils
	sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	sudo yum -y install docker-ce docker-ce-cli containerd.io
 	sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	createDaemonJson
	sudo systemctl start docker
}

uninstallDocker(){
	echo -e "${Color_Off}Uninstalling Docker...${BGreen}Started"
	sudo docker network prune
	sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-ce docker-ce-cli docker-scan-plugin
	sudo rm -rf /etc/docker
	sudo rm -rf /run/docker
	sudo rm -rf /var/lib/docker
	sudo rm -rf /var/run/docker
	sudo rm -rf /usr/bin/docker
	sudo rm -rf /usr/local/bin/docker-compose
	sudo rm -rf /usr/libexec/docker
	sudo rm -rf /usr/share/man/man1/docker.1.gz
	sudo rm -rf /usr/share/man/man8/dockerd.8.gz
}

checkDockerInstallationSuccess(){	
	if ! yum list installed "docker-ce" >/dev/null 2>&1; then
    		echo -e "${Color_Off}Installing Docker...${BRed}Failed. Cannot continue till docker is installed.${Color_Off}"
		exit
  	fi
}

createHTMLReadMeFile(){
	upperCaseDatabaseInstance=${config_db_instance^^}
	lowerCaseDatabaseInstance=${config_db_instance,,}
	
	echo "<!DOCTYPE html>" > "$readMeDirectory/index.html"
	echo "<html lang=\"en\">" >> "$readMeDirectory/index.html"
	echo "<head>" >> "$readMeDirectory/index.html"
	echo "	<meta charset=\"UTF-8\" />" >> "$readMeDirectory/index.html"
	echo "	<title>Information for Instance $upperCaseDatabaseInstance</title>" >> "$readMeDirectory/index.html"
	echo "	<style>" >> "$readMeDirectory/index.html"
	echo "table{" >> "$readMeDirectory/index.html"
 	echo " border: 1px solid black;" >> "$readMeDirectory/index.html"
	echo "  border-collapse: collapse;" >> "$readMeDirectory/index.html"
	echo "  width: 80%;" >> "$readMeDirectory/index.html"
	echo "  color: #105652;" >> "$readMeDirectory/index.html"
	echo "}" >> "$readMeDirectory/index.html"
	echo "" >> "$readMeDirectory/index.html"
	echo "th, td {" >> "$readMeDirectory/index.html"
 	echo " border: 1px solid black;" >> "$readMeDirectory/index.html"
	echo "  border-collapse: collapse;" >> "$readMeDirectory/index.html"
	echo "  text-align: left;" >> "$readMeDirectory/index.html"
	echo "  padding: 8px;" >> "$readMeDirectory/index.html"
	echo "}" >> "$readMeDirectory/index.html"
	echo "" >> "$readMeDirectory/index.html"
	echo "h1,h2,a{" >> "$readMeDirectory/index.html"
	echo "  color: #B91646;" >> "$readMeDirectory/index.html"
	echo "}" >> "$readMeDirectory/index.html"
	echo "" >> "$readMeDirectory/index.html"
	echo "p,ul{" >> "$readMeDirectory/index.html"
	echo "  color:#105652;" >> "$readMeDirectory/index.html"
	echo "}" >> "$readMeDirectory/index.html"
	echo "" >> "$readMeDirectory/index.html"
	echo "tr:nth-child(even) {" >> "$readMeDirectory/index.html"
	echo "  background-color: #DFD8CA;" >> "$readMeDirectory/index.html"
	echo "}" >> "$readMeDirectory/index.html"
	echo "</style>" >> "$readMeDirectory/index.html"
	echo "</head>" >> "$readMeDirectory/index.html"
	echo "<body>" >> "$readMeDirectory/index.html"
	echo "	<h1>$upperCaseDatabaseInstance Configuration</h1>" >> "$readMeDirectory/index.html"
	echo "	<p>This page contains all the necessary URLs, GSTs and Paths for $upperCaseDatabaseInstance instance of Konami KCMS.</p>" >> "$readMeDirectory/index.html"
	echo "	<h2>Links:</h2>" >> "$readMeDirectory/index.html"
	echo "		<table>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<th>Service</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Name</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Path</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Comment</th>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	if $needIWare; then	 
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>IWare</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Status Page</td>" >> "$readMeDirectory/index.html"
		echo "				<td><a href=\"http://$config_server_host:$config_iware_webPort/Status.htm\" target=\"_blank\">http://$config_server_host:$config_iware_webPort/Status.htm</a></td>" >> "$readMeDirectory/index.html"
		echo "				<td>Page used to monitor the health and status of IWare Service.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"
	fi
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Health Check</td>" >> "$readMeDirectory/index.html"
	echo "				<td><a href=\"https://$config_server_host:$config_kweb_adminPort/healthCheck\" target=\"_blank\">https://$config_server_host:$config_kweb_adminPort/healthCheck</a></td>" >> "$readMeDirectory/index.html"
	echo "				<td>This URL is a quick glance HTML Page to verify the Synkros API is healthy.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Logs</td>" >> "$readMeDirectory/index.html"
	echo "				<td><a href=\"https://$config_server_host:$config_kweb_apiPort/static\" target=\"_blank\">https://$config_server_host:$config_kweb_apiPort/static</a></td>" >> "$readMeDirectory/index.html"
	echo "				<td>This URL is where the logs can be found for the API Server.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Swagger</td>" >> "$readMeDirectory/index.html"
	echo "				<td><a href=\"https://$config_server_host:$config_kweb_apiPort/docs\" target=\"_blank\">https://$config_server_host:$config_kweb_apiPort/docs</a></td>" >> "$readMeDirectory/index.html"
	echo "				<td>Page used to directly call Synkros API Business methods.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>"	 >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>UI Monitor</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Logs</td>" >> "$readMeDirectory/index.html"
	echo "				<td><a href=\"http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Monitor/monitor.log\" target=\"_blank\">http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Monitor/monitor.log</a></td>" >> "$readMeDirectory/index.html"
	echo "				<td>This URL is the location of the logs for the UI Monitor Service.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	if $config_rabbitmq_enable; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Rabbit MQ</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Admin Page</td>" >> "$readMeDirectory/index.html"
		echo "				<td><a href=\"http://$config_server_host:$config_rabbitmq_adminPort/#/\" target=\"_blank\">http://$config_server_host:$config_rabbitmq_adminPort/#/</a></td>" >> "$readMeDirectory/index.html"
		echo "				<td>Page used to monitor the health and status of Rabbit MQ Server</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"
	fi
	if $config_ui_monitor_synk31Enabled; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Synk 31</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Web Forms</td>" >> "$readMeDirectory/index.html"
		echo "				<td><a href=\"http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Synk31/#\" target=\"_blank\">http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Synk31/#</a></td>" >> "$readMeDirectory/index.html"
		echo "				<td>This URL is the location of the Web pages that make up the Synk31 Web Forms.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"	
	fi
	if $config_ui_monitor_helpEnabled; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Synkros</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Help Docs</td>" >> "$readMeDirectory/index.html"
		echo "				<td><a href=\"http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Help/master_index.html\" target=\"_blank\">http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Help/master_index.html</a></td>" >> "$readMeDirectory/index.html"
		echo "				<td>This URL is the location of the web pages that make up the Synkros Help Documentation.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"
	fi	
	if $config_ui_monitor_synkUIEnabled; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Synkros</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Web Forms</td>" >> "$readMeDirectory/index.html"
		echo "				<td><a href=\"http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Synkros-UI/#\" target=\"_blank\">http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Synkros-UI/#</a></td>" >> "$readMeDirectory/index.html"
		echo "				<td>This URL is the location of the Web pages that make up the Synkros Web Forms.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"
	fi
	echo "		</table>" >> "$readMeDirectory/index.html"
	echo "	<h2>GST Properties:</h2>" >> "$readMeDirectory/index.html"
	echo "		<table>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<th>Service</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Property</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Value</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Description</th>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	if $config_rabbitmq_enable; then		
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Rabbit MQ</td>" >> "$readMeDirectory/index.html"
		echo "				<td>paradigm.ems.messaging.uri</td>" >> "$readMeDirectory/index.html"
		echo "				<td>amqp://konami:konami123@$config_server_host:$config_rabbitmq_mqPort</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This GST tells Synkros KonamiWeb & IWare what Rabbit MQ Server to use and how to connect.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"
	fi
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>Synkros</td>" >> "$readMeDirectory/index.html"
	echo "				<td>konami.ui.uri</td>" >> "$readMeDirectory/index.html"
	echo "				<td>http://$config_server_host:$config_ui_monitor_port/$lowerCaseDatabaseInstance/Synkros-UI/#</td>" >> "$readMeDirectory/index.html"
	echo "				<td>This GST tells Synkros where to find the Synkros UI Forms.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>konami.web.uri</td>" >> "$readMeDirectory/index.html"
	echo "				<td>https://$config_server_host:$config_kweb_apiPort</td>" >> "$readMeDirectory/index.html"
	echo "				<td>This GST tells Synkros where to find the Synkros API Business Methods.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"	
	echo "		</table>" >> "$readMeDirectory/index.html"	
	echo "	<h2>Paths:</h2>" >> "$readMeDirectory/index.html"
	echo "		<table>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<th>Service</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Folder</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Location</th>" >> "$readMeDirectory/index.html"
	echo "				<th>Description</th>" >> "$readMeDirectory/index.html"
	echo "			</tr>"  >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>All</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Certs</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$konamiWebCertsDirectory</td>" >> "$readMeDirectory/index.html"
	echo "				<td>This is the location of the SSL Certificates that is being used in the Synkros API for this server.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>"	 >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>All</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Stores</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$konamiWebStoresDirectory</td>" >> "$readMeDirectory/index.html"
	echo "				<td>This is the location of the keystore that is being used in the Synkros API to store certificates for this server.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	if $needIWare; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>IWare</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Bin</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$iWareBinDirectory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is location of the jars for IWare Server.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>"  >> "$readMeDirectory/index.html"			
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>IWare</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Config</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$iWareConfigDirectory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is where an admin can see the configuration files for IWare Server.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>"  >> "$readMeDirectory/index.html"		
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>IWare</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Logs</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$iWareLogsDirectory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is where an admin can see the logs created by IWare Server.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>" >> "$readMeDirectory/index.html"
	fi	
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Bin</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$konamiWebBinDirectory</td>"  >> "$readMeDirectory/index.html"
	echo "				<td>This is the location of jars files used by Synkros API.</td>"  >> "$readMeDirectory/index.html"
	echo "			</tr>"   >> "$readMeDirectory/index.html"				
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Config</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$konamiWebConfigDirectory</td>"  >> "$readMeDirectory/index.html"
	echo "				<td>This is the location of configuration files created for Synkros API.</td>"  >> "$readMeDirectory/index.html"
	echo "			</tr>"   >> "$readMeDirectory/index.html"				
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>KonamiWeb API</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Logs</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$konamiWebLogsDirectory</td>"  >> "$readMeDirectory/index.html"
	echo "				<td>This is the location of logs generated by the Synkros API.</td> " >> "$readMeDirectory/index.html"
	echo "			</tr>"  >> "$readMeDirectory/index.html" 				
	if $config_rabbitmq_enable; then				
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Rabbit MQ</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Logs</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$rabbitMQLogsDirectory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is where an admin can see the logs created by Rabbit MQ Server.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>"  >> "$readMeDirectory/index.html"
	fi
	if $config_ui_monitor_synkUIEnabled; then
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Synkros</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Synkros-UI</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$synkrosUIDirectory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is the path that the Synkros web forms are stored.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>"	 >> "$readMeDirectory/index.html"
	fi
	if $config_ui_monitor_synk31Enabled; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Synk 31</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Synk31</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$synk31Directory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is the path that the Synk 31 web forms are stored.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>"	 >> "$readMeDirectory/index.html"
	fi
	if $config_ui_monitor_helpEnabled; then	
		echo "			<tr>" >> "$readMeDirectory/index.html"
		echo "				<td>Synkros</td>" >> "$readMeDirectory/index.html"
		echo "				<td>Help</td>" >> "$readMeDirectory/index.html"
		echo "				<td>$synkrosHelpDirectory</td>" >> "$readMeDirectory/index.html"
		echo "				<td>This is the path that the Synkros help docs are stored.</td>" >> "$readMeDirectory/index.html"
		echo "			</tr>"	 >> "$readMeDirectory/index.html"
	fi
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>UI Monitor</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Config</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$synkUIConfigDirectory</td>" >> "$readMeDirectory/index.html"
	echo "				<td>This is the path containing the configuration for the SynkUI Monitor. The monitor watches the database for any changes to the Synkros-UI. If the UI is updated the monitor will replace the files with the new files in the database.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>UI Monitor</td>" >> "$readMeDirectory/index.html"
	echo "				<td>Logs</td>" >> "$readMeDirectory/index.html"
	echo "				<td>$synkUILogsDirectory</td>" >> "$readMeDirectory/index.html"
	echo "				<td>This is the path containing the logs for the SynkUI Monitor. The monitor watches the database for any changes to the Synkros-UI. If the UI is updated the monitor will replace the files with the new files in the database.</td>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"					
	echo "		</table>" >> "$readMeDirectory/index.html"
	echo "	<h2>Database:</h2>">> "$readMeDirectory/index.html"
	echo "	<p>These services have been connected to the database at.</p>">> "$readMeDirectory/index.html"
	echo "		<table>" >> "$readMeDirectory/index.html"
	echo "			<tr>" >> "$readMeDirectory/index.html"
	echo "				<td>(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = $config_db_host)(PORT = $config_db_port)) ) (CONNECT_DATA = (SERVICE_NAME = $config_db_instance.$config_db_host) ) )</th>" >> "$readMeDirectory/index.html"
	echo "			</tr>" >> "$readMeDirectory/index.html"
	echo "		</table>" >> "$readMeDirectory/index.html"	
	echo "	<h2>Ports:</h2>" >> "$readMeDirectory/index.html"
	echo "	<p>With the given configuration the following ports need to be open for these services to function.</p>" >> "$readMeDirectory/index.html"
	echo "	<ul>" >> "$readMeDirectory/index.html"
	echo "		<li>$config_db_port</li>" >> "$readMeDirectory/index.html"
	echo "		<li>$config_kweb_apiPort</li>" >> "$readMeDirectory/index.html"
	echo "		<li>$config_kweb_adminPort</li>" >> "$readMeDirectory/index.html"
	if $config_rabbitmq_enable; then	
		echo "		<li>$config_rabbitmq_mqPort</li>" >> "$readMeDirectory/index.html"
		echo "		<li>$config_rabbitmq_adminPort</li>" >> "$readMeDirectory/index.html"
	fi
	echo "		<li>$config_ui_monitor_port</li>" >> "$readMeDirectory/index.html"
	echo "		<li>$config_ui_monitor_sslPort</li>" >> "$readMeDirectory/index.html"
	if $needIWare; then
		echo "		<li>$config_iware_webPort</li>" >> "$readMeDirectory/index.html"
		echo "		<li>$config_iware_cmdPort</li>" >> "$readMeDirectory/index.html"
		echo "		<li>$config_iware_mobilePort</li>" >> "$readMeDirectory/index.html"
	fi
	echo "	</li>" >> "$readMeDirectory/index.html"
	echo "</body>" >> "$readMeDirectory/index.html"
	echo "</html>" >> "$readMeDirectory/index.html"
}

ask() {
	# http://djm.me/ask
	local prompt default REPLY

	while true; do
		if [ "${2:-}" = "Y" ]; then
			prompt="Y/n"
			default=Y
		elif [ "${2:-}" = "N" ]; then
			prompt="y/N"
			default=N
		else
			prompt="y/n"
			default=
		fi

		# Ask the question (not using "read -p" as it uses stderr not stdout)
		echo -ne "$1 [$prompt] "
		
		# Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
		read REPLY </dev/tty
		
		# Default?
		if [ -z "$REPLY" ]; then
			REPLY=$default
		fi

		# Check if the reply is valid
		case "$REPLY" in
		Y*|y*) return 0 ;;
		N*|n*) return 1 ;;
		esac
	done
}

installationHeader(){
echo -e "${Color_Off}================================================================";
echo -e "${BRed} _   __                                 _    ___  ______  _____ ";
echo -e "${BRed}| | / /                                (_)  / _ \ | ___ \|_   _|";
echo -e "${BRed}| |/ /   ___   _ __    __ _  _ __ ___   _  / /_\ \| |_/ /  | |  ";
echo -e "${BRed}|    \  / _ \ | '_ \  / _\` || '_ \` _ \ | | |  _  ||  __/   | |  ";
echo -e "${BRed}| |\  \| (_) || | | || (_| || | | | | || | | | | || |     _| |_ ";
echo -e "${BRed}\_| \_/ \___/ |_| |_| \__,_||_| |_| |_||_| \_| |_/\_|     \___/ ";
echo -e "${BRed} _____                                                          ";
echo -e "${BRed}/  ___|                                                         ";
echo -e "${BRed}\ \`--.   ___  _ __ __   __ ___  _ __                            ";
echo -e "${BRed} \`--. \ / _ \| '__|\ \ / // _ \| '__|                           ";
echo -e "${BRed}/\__/ /|  __/| |    \ V /|  __/| |                              ";
echo -e "${BRed}\____/  \___||_|     \_/  \___||_|                              ";
echo -e "${BRed} _____             _          _  _         _    _               ";
echo -e "${BRed}|_   _|           | |        | || |       | |  (_)              ";
echo -e "${BRed}  | |  _ __   ___ | |_  __ _ | || |  __ _ | |_  _   ___   _ __  ";
echo -e "${BRed}  | | | '_ \ / __|| __|/ _\` || || | / _\` || __|| | / _ \ | '_ \ ";
echo -e "${BRed} _| |_| | | |\__ \| |_| (_| || || || (_| || |_ | || (_) || | | |";
echo -e "${BRed} \___/|_| |_||___/ \__|\__,_||_||_| \__,_| \__||_| \___/ |_| |_|";
echo -e "${BRed}                                                                ";
echo -e "${Color_Off}================================================================";
echo -e "${Color_Off} Version:	${BGreen}1.0.0";
echo -e "${Color_Off} Copyright:	${BGreen}Copyright (c) 2021";
echo -e "${Color_Off} Author:	${BGreen}Steven Christman";
echo -e "${Color_Off} Company:	${BGreen}Konami Gaming, Inc. - Systems R&D";
echo -e "${Color_Off}================================================================";
}
	
# Shell Color Escapes

# Reset
Color_Off='\033[0m'       # Text Reset

# Bold Colors
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'
run_config='NO'
var_host_api='127.0.0.1'

main "$@"