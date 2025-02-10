if [ -f .env ]; then
    echo ".env file exists"
    export $(cat .env | xargs)
    cat .env
else
    echo ".env file does not exist. Please debug previous jobs."
    exit 1
fi  