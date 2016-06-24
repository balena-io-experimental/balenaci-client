IMAGE=localhost/dind-generator-client:latest

all: build

build:
	docker build -t ${IMAGE} .

run: build
	docker run -it --rm \
		-v $$(pwd):/mnt \
		${IMAGE}

shell: build
	docker run -it --rm \
		-v $$(pwd):/mnt \
		--entrypoint /bin/sh \
		${IMAGE}

