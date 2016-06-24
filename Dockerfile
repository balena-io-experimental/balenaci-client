FROM library/docker:1.10.3

WORKDIR /usr/src/app

ENTRYPOINT ["/usr/bin/bundle"]
CMD ["exec", "client.rb"]

RUN apk update \
	&& apk add \
		build-base \
		libffi-dev \
		ruby \
		ruby-dev \
		ruby-bundler \
		ruby-json

COPY secrets /root/.docker

COPY Gemfile .
RUN bundle -j 4

COPY . .

