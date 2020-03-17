# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'

module JavaBuildpack
  module Framework

    # Looks for certificates and PEM files within the application context and
    # injects them into the default java cacerts keystore.
    class KeystoreInjector < JavaBuildpack::Component::BaseComponent

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger KeystoreInjector
        @keystore  = store
        @pem_path = pem_path
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @keystore && @pem_path ? KeystoreInjector.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts "#{'Keystore Injector'.blue.bold} processing PEMs at #{@configuration['path']}"
        @pem_path.children {|f|
          pemport = "#{qualify_path @droplet.java_home.root, @droplet.root}/bin/keytool -import " +
                    "-file #{qualify_path f, @droplet.root} -alias #{f.basename} -storepass #{password} " +
                    "-keystore #{qualify_path @keystore, @droplet.root} -noprompt -storetype JKS"
          puts "#{'----->'.red.bold} #{pemport}"
        }
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        puts "#{'Keystore Injector'.blue.bold} completed import from #{@configuration['path']}"
      end

      private

      def valid_path(basepath, subpath)
        unless subpath.nil? || !subpath.kind_of?(String) || subpath.empty?
          fullpath = basepath + storepath
          if fullpath.exist?
            fullpath
          end
        end
      end

      def store
        valid_path(@droplet.java_home.root, @configuration['store'])
      end

      def pem_path
        valid_path(@application.root, @configuration['pem_path'])
      end

      def password
        @configuration['password'] || 'changeit'
      end
    end
  end
end
