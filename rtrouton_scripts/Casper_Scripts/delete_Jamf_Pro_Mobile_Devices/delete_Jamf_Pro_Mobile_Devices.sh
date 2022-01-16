#!/bin/bash

##########################################################################################
# 	Mobile Device Delete Script for Jamf Pro
#
#	Original script by Randy Saeks:
#	https://github.com/rsaeks/scripts/blob/master/delMobileDevice.sh
#
#	Please create a backup of the Jamf Pro database prior to deleting mobile devices
#
#	Usage: Call script with the following four parameters
#			- a text file containing the Jamf Pro IDs of the mobile device(s) you wish to delete.
#			- The URL of the appropriate Jamf Pro server
#			- username for an account on the Jamf Pro server with sufficient privileges
#			  to delete mobile devices from the Jamf Pro server.
#			- password for the account on the Jamf Pro server
#
#	Example:	./delete_Jamf_Pro_Mobile_Devices.sh jamf_pro_id_numbers.txt
#
##########################################################################################

filename="$1"
ERROR=0

# If you're on Jamf Pro 10.34.2 or earlier, which doesn't support using Bearer Tokens
# for Classic API authentication, set the NoBearerToken variable to the following value
# as shown below:
#
# yes
#
# NoBearerToken="yes"
#
# If you're on Jamf Pro 10.35.0 or later, which does support using Bearer Tokens
# for Classic API authentication, set the NoBearerToken variable to the following value
# as shown below:
#
# NoBearerToken=""

NoBearerToken=""

GetJamfProAPIToken() {

# This function uses Basic Authentication to get a new bearer token for API authentication.

# Use user account's username and password credentials with Basic Authorization to request a bearer token.

if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
   api_token=$(/usr/bin/curl -X POST --silent -u "${jamfpro_user}:${jamfpro_password}" "$jamfpro_url/api/v1/auth/token" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
else
   api_token=$(/usr/bin/curl -X POST --silent -u "${jamfpro_user}:${jamfpro_password}" "$jamfpro_url/api/v1/auth/token" | plutil -extract token raw -)
fi

}

APITokenValidCheck() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

api_authentication_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "$jamfpro_url/api/v1/auth" --request GET --header "Authorization: Bearer ${api_token}")

}

CheckAndRenewAPIToken() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

APITokenValidCheck

# If the api_authentication_check has a value of 200, that means that the current
# bearer token is valid and can be used to authenticate an API call.


if [[ ${api_authentication_check} == 200 ]]; then

# If the current bearer token is valid, it is used to connect to the keep-alive endpoint. This will
# trigger the issuing of a new bearer token and the invalidation of the previous one.

      if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
         api_token=$(/usr/bin/curl "$jamfpro_url/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${api_token}" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
      else
         api_token=$(/usr/bin/curl "$jamfpro_url/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${api_token}" | plutil -extract token raw -)
      fi

else

# If the current bearer token is not valid, this will trigger the issuing of a new bearer token
# using Basic Authentication.

   GetJamfProAPIToken
fi
}

InvalidateToken() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

APITokenValidCheck

# If the api_authentication_check has a value of 200, that means that the current
# bearer token is valid and can be used to authenticate an API call.

if [[ ${api_authentication_check} == 200 ]]; then

# If the current bearer token is valid, an API call is sent to invalidate the token.

      authToken=$(/usr/bin/curl "$jamfpro_url/api/v1/auth/invalidate-token" --silent  --header "Authorization: Bearer ${api_token}" -X POST)
      
# Explicitly set value for the api_token variable to null.

      api_token=""

fi
}

if [[ -n $filename && -r $filename ]]; then

	# If you choose to hardcode API information into the script, uncomment the lines below
	# and set one or more of the following values:
	#
	# The username for an account on the Jamf Pro server with sufficient API privileges
	# The password for the account
	# The Jamf Pro URL

	#jamfpro_url=""	## Set the Jamf Pro URL here if you want it hardcoded.
	#jamfpro_user=""		## Set the username here if you want it hardcoded.
	#jamfpro_password=""		## Set the password here if you want it hardcoded.


	# If you do not want to hardcode API information into the script, you can also store
	# these values in a ~/Library/Preferences/com.github.jamfpro-info.plist file.
	#
	# To create the file and set the values, run the following commands and substitute
	# your own values where appropriate:
	#
	# To store the Jamf Pro URL in the plist file:
	# defaults write com.github.jamfpro-info jamfpro_url https://jamf.pro.server.goes.here:port_number_goes_here
	#
	# To store the account username in the plist file:
	# defaults write com.github.jamfpro-info jamfpro_user account_username_goes_here
	#
	# To store the account password in the plist file:
	# defaults write com.github.jamfpro-info jamfpro_password account_password_goes_here
	#
	# If the com.github.jamfpro-info.plist file is available, the script will read in the
	# relevant information from the plist file.

	if [[ -f "$HOME/Library/Preferences/com.github.jamfpro-info.plist" ]]; then

	     if [[ -z "$jamfpro_url" ]]; then
	          jamfpro_url=$(defaults read $HOME/Library/Preferences/com.github.jamfpro-info jamfpro_url)
	     fi

	     if [[ -z "$jamfpro_user" ]]; then
	          jamfpro_user=$(defaults read $HOME/Library/Preferences/com.github.jamfpro-info jamfpro_user)
	     fi

	     if [[ -z "$jamfpro_password" ]]; then
	          jamfpro_password=$(defaults read $HOME/Library/Preferences/com.github.jamfpro-info jamfpro_password)
	     fi

	fi

	# If the Jamf Pro URL, the account username or the account password aren't available
	# otherwise, you will be prompted to enter the requested URL or account credentials.

	if [[ -z "$jamfpro_url" ]]; then
	     read -p "Please enter your Jamf Pro server URL : " jamfpro_url
	fi

	if [[ -z "$jamfpro_user" ]]; then
	     read -p "Please enter your Jamf Pro user account : " jamfpro_user
	fi

	if [[ -z "$jamfpro_password" ]]; then
	     read -p "Please enter the password for the $jamfpro_user account: " -s jamfpro_password
	fi
	
	echo ""

	# Remove the trailing slash from the Jamf Pro URL if needed.

	jamfpro_url=${jamfpro_url%%/}

	# Set up the Jamf Pro Mobile Devices ID URL
	jamfproIDURL="${jamfpro_url}/JSSResource/mobiledevices/id"
	
	if [[ -z "$NoBearerToken" ]]; then
	   GetJamfProAPIToken
	fi

	while read -r ID
	do

		# Verify that the input is a number. All Jamf Pro
		# IDs are positive numbers, so any other input will
		# not be a valid Jamf Pro ID.

		if [[ "$ID" =~ ^[0-9]+$ ]]; then

		  # The line below previews the results of the 
		  # deletion command. Comment out the line below
		  # if this preview is not desired.

		  echo "curl -X DELETE ${jamfproIDURL}/$ID"

		  # The lines below runs the deletion command.
		  # Comment out the lines below if you want to
		  # only simulate running the deletion command.

		  if [[ -z "$NoBearerToken" ]]; then
		  	  CheckAndRenewAPIToken
		  	  /usr/bin/curl --header "Authorization: Bearer ${api_token}" -X DELETE "${jamfproIDURL}/$ID"   
		  else
		  	  /usr/bin/curl -u "${jamfpro_user}:${jamfpro_password}" -X DELETE "${jamfproIDURL}/$ID"
		  fi

		else
		   echo "All Jamf Pro IDs are expressed as numbers. The following input is not a number: $ID"
		fi
	done < "$filename"

else
	echo "Input file does not exist or is not readable"
	ERROR=1
fi

exit "$ERROR"