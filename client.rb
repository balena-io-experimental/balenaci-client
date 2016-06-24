#!/usr/bin/env ruby

require 'yaml'
require 'bundler'
Bundler.require

module Resin
  class Config
    class << self
      def load(path)
        config = Travis::Yaml.parse(File.read("/mnt/.resin.yml"))

        unless config.services.include?("docker")
          STDERR.puts "you must include docker as a service to use this tool!"
          exit 1
        end

        config
      end
    end
  end

  class Client
    def initialize(path)
      @config = Config.load(path)
    end

    def env
      return @env if @env

      @env = {}
      @config.env.matrix.each do |var|
        k,v = var.split("=")

        @env[k.downcase.to_sym] = v
      end

      puts @env.inspect

      validate_env

      @env
    end

    def subdomain
      @subdomain ||= (env[:docker_version] =~ /-rc/) ? "test" : "get"
    end

    def version
      @version ||= env[:docker_version]
    end

    def namespace
      @namespace ||= env[:dind_namespace]
    end

    def clean
      `rm -rf docker.tgz docker`
    end

    def install
      # Download the docker client we'll need
      shell "curl https://#{subdomain}.docker.com/builds/Linux/x86_64/docker-#{version}.tgz > docker.tgz"
      shell "tar -xf docker.tgz"
    end

    def provision
      creds = HTTParty.get("http://docker01.dev.resin.io:8080/dockers/create", query: {
        version: version,
        context: namespace,
      })

      File.open("/tmp/dind-env.sh", "w") do |f|
        f.puts creds.body
        f.puts "DOCKER_TLS_VERIFY=1; export DOCKER_TLS_VERIFY"
      end
    end

    def run
      clean
      install
      provision
      build
    end

    def build
      context "export PATH=./docker:$PATH" do
        "docker --version"
        "source /tmp/dind-env.sh && docker info"

      end

      @config.script.each do |script|
        context "export PATH=./docker:$PATH; source /tmp/dind-env.sh && cd /mnt" do
          script
        end
      end
    end

    def shell(cmd)
      puts `#{cmd}`
    end

    def context(str, &block)
      cmd = yield

      shell("%s && %s" % [str, cmd])
    end

    private

    def validate_env
      unless version
        raise ArgumentError, "you must set the DOCKER_VERSION env var!"
      end

      unless namespace
        raise ArgumentError, "you must set the DIND_NAMESPACE env var!"
      end
    end
  end
end

client = Resin::Client.new("/mnt/.resin.yml")
client.run

