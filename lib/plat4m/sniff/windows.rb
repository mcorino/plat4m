# Copyright (c) 2023 M.J.N. Corino, The Netherlands
#
# This software is released under the MIT license.
#
# Plat4m Windows sniffer


module Plat4m

  module Sniffer

    module Windows

      class << self

        def detect_system
          # determine system platform
          System.new(System::Platform.new(arch: get_arch, cpus: get_cpu_count),
                     System::OS.new(id: :windows, **get_distro))
        end

        private

        def get_arch
          arch, _ = RbConfig::CONFIG['arch'].split('-')
          arch = 'x86' if arch =~ /i\d86/
          arch
        end

        def get_cpu_count
          ENV['NUMBER_OF_PROCESSORS'].to_i
        end

        def get_distro
          distro = {
            distro: RUBY_PLATFORM.match?(/mingw/i) ? 'mingw' : 'windows'
          }
          # the 'ver' command outputs something like "Microsoft Windows [Version xx.xx.xx.xx]"
          # the 'for ...' statement parses this and echos only the 'xx.xx.xx.xx' part
          ver = `for /f "tokens=2 delims=[]" %s in ('ver') do @(for /f "tokens=2" %v in ('echo %s') do @echo %v)`.strip
          distro[:version] = ver
          build = ver.split('.')[2].to_i
          distro[:release] = if build >= 22000
                               '11'
                             elsif build >= 10240
                               '10'
                             else
                               '<10'
                             end
          # in case of MingW built Ruby assume availability of RubyInstaller Devkit
          distro[:pkgman] = distro[:distro]=='mingw' ? Pacman.new(distro) : nil
          distro
        end

      end

      class Pacman < PkgManager

        def initialize(_distro)
          super()
        end

        def make_install_command(*pkgs)
          pacman_cmd("-S --needed #{ pkgs.join(' ') }")
        end

        def install(*pkgs, silent: false)
          run(make_install_command, silent: silent)
        end

        def make_uninstall_command(*pkgs)
          pacman_cmd("-Rsu #{pkgs.flatten.join(' ')}")
        end

        def installed?(pkg)
          run("pacman -Qq #{pkg}", silent: true)
        end

        def available?(pkg)
          run(%Q[pacman -Ss '^#{pkg}$'], silent: true)
        end

        protected

        def run(cmd, silent: false)
          system(%Q[bash -c "#{cmd}#{silent ? ' >/dev/null 2>&1' : ''}"])
        end

        def pacman_cmd(cmd)
          "pacman --noconfirm #{cmd}"
        end

      end

    end

  end

  self.sniffers[:windows] = Sniffer::Windows

end
