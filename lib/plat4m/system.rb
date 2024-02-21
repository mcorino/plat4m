# Copyright (c) 2023 M.J.N. Corino, The Netherlands
#
# This software is released under the MIT license.
#
# Plat4m System class


module Plat4m

  # Instances of this class identify a system and provide access to system management support.
  class System

    # Provides information about the hardware platform.
    class Platform

      def initialize(arch: nil, cpus: nil)
        @arch = arch
        @bits = @arch.to_s =~ /64/ ? 64 : 32
        @cpus = cpus
      end

      attr_reader :arch, :bits, :cpus

      def complete?
        ::String === @arch && !@arch.empty? &&
          ::Integer === cpus && @cpus>0
      end

      def to_s
        "[#{@arch}: #{@bits}bits, #{cpus} cpu]"
      end

    end

    # Provides information about the operating system.
    class OS

      def initialize(id: nil, distro: nil, variant: nil, release: nil, pkgman: nil, **other)
        @id = id
        @distro = distro
        @variant = variant
        @release = release
        @pkgman = pkgman
        @other = other
        @other.each_key do |key|
          unless self.respond_to?(key.to_sym)
            singleton_class.class_eval <<~__CODE
              define_method(:#{key}) do
                @other['#{key}']
              end
            __CODE
          end
        end
      end

      attr_reader :id, :distro, :release, :pkgman

      def variant
        @variant || @distro
      end

      alias :distribution :distro

      def complete?
        ::Symbol === @id &&
          ::String === @distro && !@distro.empty?
          ::String === @release && !@release.empty?
      end

      def is_root?
        @pkgman ? @pkgman.is_root? : false
      end

      def has_sudo?
        @pkgman ? @pkgman.has_sudo? : false
      end

      def to_s
        "#{@distro}-#{@release}[#{@id}#{@variant ? " #{@variant}" : ''}}]"
      end

    end

    def initialize(platform, os)
      unless platform && platform.complete? && os && os.complete?
        raise "Invalid system specification [#{os} @ #{platform}]"
      end
      @platform = platform
      @os = os
    end

    attr_reader :platform, :os

    def kind
      "#{@platform.arch}-#{@os.id}"
    end

    def intel?
      @platform.arch =~ /x86/
    end

    def arm?
      @platform.arch =~ /arm/
    end

    def bits
      @platform.bits
    end

    def cpu_count
      @platform.cpus
    end

    def linux?
      @os.id == :linux
    end

    def windows?
      @os.id == :windows
    end

    def darwin?
      @os.id == :darwin
    end

    def macosx?
      darwin? && @os.distro == 'MacOSX'
    end
    alias :osx? :macosx?

    def freebsd?
      @os.id == :freebsd
    end

    def dev_null
      windows? ? 'NUL' : '/dev/null'
    end

  end

  class << self

    # Returns System instance for current system.
    def current
      @current ||= detect_current
    end

    # System sniffer registry.
    def sniffers
      @sniffers ||= {}
    end

    def detect_current
      case RbConfig::CONFIG['host_os']
      when /linux/
        sniffers[:linux].detect_system
      when /darwin/
        sniffers[:darwin].detect_system
      when /freebsd/
        sniffers[:freebsd].detect_system
      else
        if ENV['OS'] =~ /windows/i
          sniffers[:windows].detect_system
        else
          raise "Unknown system!"
        end
      end
    end
    private :detect_current

  end

end

require_relative 'pkgman'
require_relative 'sniff/darwin'
require_relative 'sniff/linux'
require_relative 'sniff/windows'
require_relative 'sniff/freebsd'
