
DEPLOY_IMAGE_TAG = sauthnio:latest

# Use this if your SPM project requires secure access to Gitlab
#ID_RSA_PATH = ~/.ssh/id_rsa
#ID_RSA_NAME = `basename ${ID_RSA_PATH}`
PROJECT_NAME = SAuthNIO
PROJECT_NAME_LOWER = `echo ${PROJECT_NAME} | tr '[:upper:]' '[:lower:]'`
HOME_DIR = $(cd ; pwd)
SWIFT_BUILD_IMAGE = ${PROJECT_NAME_LOWER}_buildenv:latest
BASE_IMAGE = ${PROJECT_NAME_LOWER}_base:latest
BUILD_ENV_DIR = .dockerbuildenv
DOCKER_PREFIX = docker run "--volume=${PWD}:/swiftbuild" \
		"--volume=${PWD}/.build_lin:/swiftbuild/.build" \
		"--volume=${PWD}/.package_lin.resolved:/swiftbuild/Package.resolved" \
		--volume=/private/var:/private/var \
		--workdir=/swiftbuild \
		--rm
BIN_NAME = .build_lin/release/${PROJECT_NAME}

all: help
	
help:
	@echo "Usage:"
	@echo " make clean	- remove all linux build artifacts"
	@echo " make buildenv	- create initial build environment images"
	@echo " make update	- swift package update for linux"
	@echo " make linux	- compile for linux release"
	@echo " make image	- create deployment image from linux release build"
	@echo " make keys	- generate the JWT keys if they do not exist"
	@echo " make run	- run SAuth locally on port 8000"

.package_lin.resolved:
	echo "{\"object\": {\"pins\": []}, \"version\":1}" > $@

${BUILD_ENV_DIR}:
	@mkdir -p $@
	@rm -rf ${BUILD_ENV_DIR}/*

clean: 
	rm -rf .build_lin .package_lin.resolved ${BUILD_ENV_DIR}

base_image: ${BUILD_ENV_DIR}
	cp -f Dockerfile_base ${BUILD_ENV_DIR}/Dockerfile
	cd ${BUILD_ENV_DIR} && \
		docker build . -t ${BASE_IMAGE}	

buildenv: base_image
	cp -f Dockerfile_buildenv ${BUILD_ENV_DIR}/Dockerfile
	cd ${BUILD_ENV_DIR} && \
		docker build . -t ${SWIFT_BUILD_IMAGE}
	#cd ${BUILD_ENV_DIR} && cp ${ID_RSA_PATH} . && \
		docker build . -t ${SWIFT_BUILD_IMAGE} --build-arg SSH_PRIVATE_KEY=${ID_RSA_NAME} && \
		rm -f ${ID_RSA_NAME}

linux: .package_lin.resolved
	${DOCKER_PREFIX} ${SWIFT_BUILD_IMAGE} \
		swift build -c release -Xswiftc -DDEPLOY -Xswiftc -DRELEASE

update: .package_lin.resolved
	${DOCKER_PREFIX} ${SWIFT_BUILD_IMAGE} \
		swift package update

image: ${BUILD_ENV_DIR} linux
	cp Dockerfile ${BUILD_ENV_DIR}/
	cp ${BIN_NAME} ${BUILD_ENV_DIR}/
	cp -r templates config ${BUILD_ENV_DIR}/
	mkdir ${BUILD_ENV_DIR}/webroot
	rm ${BUILD_ENV_DIR}/config/*.dev.*
	cd ${BUILD_ENV_DIR} && \
		docker build . -t ${DEPLOY_IMAGE_TAG}
	rm -rf ${BUILD_ENV_DIR}

keys: 
ifeq ($(wildcard ./config/jwtRS256.private.pem),)
	@mkdir -p config
	openssl genrsa -out config/jwtRS256.private.pem 4096 && \
		openssl rsa -in config/jwtRS256.private.pem -outform PEM \
		-pubout -out config/jwtRS256.public.pem
	@echo "Generated config/jwtRS256.private.pem & jwtRS256.public.pem"
else 
	@echo "Delete config/jwtRS256.private.pem before generating new keys"
endif

run: image
	docker run --rm -i -d --name ${PROJECT_NAME_LOWER} -p 8000:8000 ${DEPLOY_IMAGE_TAG}
