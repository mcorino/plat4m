# Copyright (c) 2023 M.J.N. Corino, The Netherlands
#
# This software is released under the MIT license.
#
# Plat4m Linux sniffer


module Plat4m

  module Sniffer

    module Darwin

      class << self

        def detect_system
          # determine system platform
          System.new(System::Platform.new(arch: get_arch, cpus: get_cpu_count),
                     System::OS.new(id: :darwin, **get_distro))
        end

        private

        def get_arch
          arch, _ = RbConfig::CONFIG['arch'].split('-')
          arch = 'x86' if arch =~ /i\d86/
          arch
        end

        def get_cpu_count
          (system('command -v nproc > /dev/null 2>&1') ? `nproc` : `getconf _NPROCESSORS_ONLN`).to_i
        end

        def get_distro
          distro = {
            distro: 'macosx'
          }
          ver = `sw_vers --productVersion`.strip
          distro[:release] = ver.split('.').first
          distro[:version] = ver
          distro[:pkgman] = MacPkgManager.new
          distro
        end

        def has_macports?
          if @has_macports.nil?
            @has_macports = system('command -v port>/dev/null')
          end
        end

        def has_homebrew?
          if @has_homebrew.nil?
            @has_homebrew = system('command -v brew>/dev/null')
          end
        end

      end

      class MacPkgManager < PkgManager

        def initialize
          super
          @has_sudo = system('command -v sudo > /dev/null')
          @has_macports = system('command -v port>/dev/null')
          @has_homebrew = system('command -v brew>/dev/null')
        end

        def installed?(pkg)
          pkg_manager.installed?(pkg)
        end

        def available?(pkg)
          pkg_manager.available?(pkg)
        end

        def make_install_command(*pkgs)
          pkg_manager.make_install_command(*pkgs)
        end

        def make_uninstall_command(*pkgs)
          pkg_manager.make_uninstall_command(*pkgs)
        end

        def macports?
          MacPorts === pkg_manager
        end

        def homebrew?
          Homebrew === pkg_manager
        end

        private

        def is_root?
          `id -u 2>/dev/null`.chomp == '0'
        end

        def has_macports?
          if @has_macports.nil?
            @has_macports = system('command -v port>/dev/null')
          end
        end

        def has_homebrew?
          if @has_homebrew.nil?
            @has_homebrew = system('command -v brew>/dev/null')
          end
        end

        class Homebrew < PkgManager

          def initialize(owner)
            super()
            @owner = owner
            @has_sudo = @owner.has_sudo?
          end

          def installed?(pkg)
            `brew list -1 --formula`.strip.split("\n").include?(pkg) ||
              `brew list -1 --cask`.strip.split("\n").include?(pkg)
          end

          def available?(pkg)
            system(%Q[brew search "/^#{pkg}$/" >/dev/null 2>&1])
          end

          def make_install_command(*pkgs)
            "brew install -q #{pkgs.join(' ')}"
          end

          def make_uninstall_command(*pkgs)
            "brew uninstall -q #{pkgs.join(' ')}"
          end

        end

        class MacPorts < PkgManager

          def initialize(owner)
            super()
            @owner = owner
            @has_sudo = @owner.has_sudo?
            @privileged = File.stat(`which port`.strip).uid == 0
          end

          def installed?(pkg)
            !(`port -q installed #{pkg}`.strip.empty?)
          end

          def available?(pkg)
            !(`port -q search --exact #{pkg}`.strip.empty?)
          end

          def make_install_command(*pkgs)
            auth_cmd("port install #{pkgs.join(' ')}")
          end

          def make_uninstall_command(*pkgs)
            auth_cmd("port uninstall #{pkgs.join(' ')}")
          end

          private

          def is_root?
            @owner.is_root?
          end

          def auth_cmd(cmd)
            raise "Cannot find 'sudo' for command [#{cmd}]" unless !@privileged || is_root? || @has_sudo
            (!@privileged || is_root?) ? cmd : "sudo #{cmd}"
          end

        end

        def pkg_manager
          unless @pkg_manager
            # # Has Ruby been installed through MacPorts?
            # if has_macports? &&
            #   expand('port -q installed installed').strip.split("\n").find { |ln| ln.strip =~ /\Aruby\d+\s/ }
            #   @pkg_manager = MacPorts.new

            # re we running without root privileges and have Homebrew installed?
            # (Ruby may be installed using Homebrew itself or using a Ruby version manager like RVM)
            if !is_root? && has_homebrew?
              @pkg_manager = Homebrew.new(self)

            # or do we have MacPorts (running either privileged or not).
            elsif has_macports?
              @pkg_manager = MacPorts.new(self)

            else
              raise RuntimeError, 'Unable to determine package manager to use!'
            end
          end
          @pkg_manager
        end

      end

    end

  end

  self.sniffers[:darwin] = Sniffer::Darwin

end
