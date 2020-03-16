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
require 'java_buildpack/container'
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/java_main_utils'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running as standalone
    # uberjars expected to be run with the java -jar command
    class JavaUberjar < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger JavaUberjar
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        uberjar ? JavaUberjar.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        release_text(classpath)
      end

      private

      UBERJAR_PROPERTY = 'uberjar'
      CLASS_PATH_PROPERTY = 'class_path'
      JAR_PATH_PROPERTY = 'jar_path'
      ARGUMENTS_PROPERTY = 'arguments'

      private_constant :UBERJAR_PROPERTY, :ARGUMENTS_PROPERTY, :CLASS_PATH_PROPERTY, :JAR_PATH_PROPERTY

      def release_text(classpath)
        target = "$PWD/#{uberjar}"
        rt =  [
                @droplet.environment_variables.as_env_vars,
                'eval',
                'exec',
                "#{qualify_path @droplet.java_home.root, @droplet.root}/bin/java",
                '$JAVA_OPTS',
                classpath,
                '-jar',
                target,
                arguments
              ].flatten.compact.join(' ')
        rt
      end

      def arguments
        @configuration[ARGUMENTS_PROPERTY]
      end

      def uberjar
        @configuration[UBERJAR_PROPERTY]
      end

      def class_path
        @configuration[CLASS_PATH_PROPERTY]
      end

      def jar_path
        @configuration[JAR_PATH_PROPERTY]
      end

      def classpath
        paths = []

        unless class_path.nil? || !class_path.kind_of?(String) || class_path.empty?
          cpc = @application.root + class_path
          if cpc.exist?
            paths.push("$PWD/#{class_path}")
          end
        end

        unless jar_path.nil? || !jar_path.kind_of?(String) || jar_path.empty?
          cpj = @application.root + jar_path
          cpj.each_child(false) {|f|
            if f.to_s.end_with?(".jar")
              paths.push("$PWD/#{jar_path}/#{f.to_s}")
            end
          }
        end

        unless @droplet.additional_libraries.empty?
          paths.push(@droplet.additional_libraries.as_classpath.sub(/-cp /, ''))
        end

        unless @droplet.root_libraries.empty?
          paths.push(@droplet.root_libraries.qualified_paths.join(':'))
        end

        if !paths.empty?
          '-cp ' + paths.join(':')
        else
          ''
        end
      end
    end
  end
end
