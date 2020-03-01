#!/usr/bin/env bash

SETTINGS_DIRECTORY="./CRITr"
MAPS_DIRECTORY="./maps"

MANAGE_PY_FILE="$SETTINGS_DIRECTORY/../manage.py"
BASE_HTML_FILE="$MAPS_DIRECTORY/templates/base.html"
SETTINGS_FILE="$SETTINGS_DIRECTORY/settings.py"

# Set the postgres database password
PASSWORD_KEY_FILEPATH="$SETTINGS_DIRECTORY/../password.key"
if ! [ -f $PASSWORD_KEY_FILEPATH ]
then 
    PASSWORD_KEY=`head /dev/urandom | tr -dc A-Za-z0-9\+=_-}\[\]\# | head -c 20 ; echo ""`
    echo $PASSWORD_KEY > $PASSWORD_KEY_FILEPATH

    echo " "
    echo "#############  ATTENTION  ##############"
    echo " "
    echo "Please change the psql user password by running the script './alter_psql_user_password.sh' with root privileges."
    echo " "
    echo "########################################"
    exit
fi



# Read the flags
DEVELOPMENT_MODE="false"
while getopts d option
do
    case "${option}"
    in
    d)  echo "In Development Mode"
        DEVELOPMENT_MODE="true";;
esac
done



# Set the value of DEBUG in the settings.py file
DEBUG_STR=$(grep "DEBUG" $SETTINGS_FILE)
if [ $DEVELOPMENT_MODE == "true" ]
then 
    echo "Setting DEBUG = True"
    if ! [ -z "$DEBUG_STR" ]; then
        sed -i "s/$DEBUG_STR/DEBUG = True/" $SETTINGS_FILE
    else
        echo "ERROR: No DEBUG setting found in settings.py"
        exit 1;
    fi
else
    echo "Setting DEBUG to False"
    if ! [ -z "$DEBUG_STR" ]; then
        sed -i "s/$DEBUG_STR/DEBUG = False/" $SETTINGS_FILE
    else
        echo "ERROR: No DEBUG setting found in settings.py"
        exit 1;
    fi
fi


# Set the secret key
echo "Creating secret key"
SECRET_KEY_FILEPATH="$SETTINGS_DIRECTORY/../secret.key"
if ! [ -f $SECRET_KEY_FILEPATH ]
then
    SECRET_KEY=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 72 ; echo ""`
    echo $SECRET_KEY > $SECRET_KEY_FILEPATH
fi



# Change the db host
echo "Setting the database host"
CURR_HOST_STR=$(grep "'HOST':.*'," $SETTINGS_FILE)
echo $CURR_HOST_STR
if [ $DEVELOPMENT_MODE == "true" ]
then
    sed -i "s/$CURR_HOST_STR/        'HOST': 'localhost',/" $SETTINGS_FILE;
else
    sed -i "s/$CURR_HOST_STR/        'HOST': '',/" $SETTINGS_FILE;
fi


# Use the downloaded jquery in development mode (as the developer may be offline, though for production the jquery CDN should be faster)
echo "Setting which jquery to use"
if [ $DEVELOPMENT_MODE == "true" ]
then
    sed -i "s/https:\/\/ajax.googleapis.com\/ajax\/libs\/jquery\/3.4.1\/jquery.min.js/{% static 'js\/jquery.js'}/" $BASE_HTML_FILE
else
    sed -i "s/{% static 'js\/jquery.js'}/https:\/\/ajax.googleapis.com\/ajax\/libs\/jquery\/3.4.1\/jquery.min.js/" $BASE_HTML_FILE
fi


# Collect static files and make migrations
echo "Collecting static and making migrations"
pipenv run python3 $MANAGE_PY_FILE collectstatic --noinput
pipenv run python3 $MANAGE_PY_FILE makemigrations
pipenv run python3 $MANAGE_PY_FILE migrate --noinput
