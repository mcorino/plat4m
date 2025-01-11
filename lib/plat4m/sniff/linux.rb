# Copyright (c) 2023 M.J.N. Corino, The Netherlands
#
# This software is released under the MIT license.
#
# Plat4m Linux sniffer


module Plat4m

  module Sniffer

    module Linux

      class << self

        def detect_system
          # determine system platform
          System.new(System::Platform.new(arch: get_arch, cpus: get_cpu_count),
                     System::OS.new(id: :linux, **get_distro))
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
          distro = if File.file?('/etc/os-release') # works with most (if not all) recent distro releases
                     data = File.readlines('/etc/os-release').reduce({}) do |hash, line|
                       val, var = line.split('=')
                       hash[val] = var.strip.gsub(/(\A")|("\Z)/, '')
                       hash
                     end
                     {
                       variant: if data['ID_LIKE']
                                  case (_v = data['ID_LIKE'].split.first.to_sym)
                                  when :ubuntu then :debian # Distro like Mint has "ID_LIKE=ubuntu debian"
                                  else _v
                                  end
                                elsif File.file?('/etc/redhat-release')
                                  :rhel
                                elsif File.file?('/etc/SUSE-brand') || File.file?('/etc/SuSE-release')
                                  :suse
                                elsif File.file?('/etc/debian_version')
                                  :debian
                                else
                                  data['ID'].to_sym
                                end,
                       distro: data['ID'].downcase,
                       release: data['VERSION_ID'] || data['BUILD_ID']
                     }
                   elsif File.file?('/etc/redhat-release')
                     data = File.read('/etc/redhat-release').strip
                     {
                       variant: :rhel,
                       distro: data.split.shift.downcase,
                       release: data =~ /\d+(\.\d+)*/ ? $~[0] : ''
                     }
                   elsif File.file?('/etc/SUSE-brand') || File.file?('/etc/SuSE-release')
                     data = File.readlines(File.file?('/etc/SUSE-brand') ? '/etc/SUSE-brand' : '/etc/SuSE-release')
                     {
                       variant: :suse,
                       distro: data.shift.split.shift.downcase,
                       release: (data.find { |s| s.strip =~ /\AVERSION\s*=/ } || '').split('=').last || ''
                     }
                   elsif File.file?('/etc/debian_version')
                     {
                       variant: :debian,
                       distro: 'generic',
                       release: File.read('/etc/debian_version').strip.split('.').shift
                     }
                   else
                     {
                     }
                   end
          distro[:pkgman] = case distro[:variant]
                            when :debian
                              Apt.new(distro)
                            when :rhel
                              Dnf.new(distro)
                            when :suse
                              Zypper.new(distro)
                            when :arch
                              Pacman.new(distro)
                            end
          distro
        end

      end

      class NixManager < PkgManager

        def initialize(distro)
          super()
          @distro = distro
          @has_sudo = system('command -v sudo > /dev/null')
        end

        def make_install_command(*pkgs)
          auth_cmd(get_install_command(*pkgs))
        end

        def make_uninstall_command(*pkgs)
          auth_cmd(get_uninstall_command(*pkgs))
        end

        protected

        def get_install_command(*pkgs)
          raise NoMethodError
        end

        def get_uninstall_command(*pkgs)
          raise NoMethodError
        end

        def is_root?
          `id -u 2>/dev/null`.chomp == '0'
        end

        def auth_cmd(cmd)
          raise "Cannot find 'sudo' for command [#{cmd}]" unless is_root? || has_sudo?
          is_root? ? cmd : "sudo #{cmd}"
        end

      end

      class Apt < NixManager

        def installed?(pkg)
          # get architecture
          system("dpkg-query -s \"#{pkg}:#{pkg_arch}\" >/dev/null 2>&1") ||
            system("dpkg-query -s \"#{pkg}:all\" >/dev/null 2>&1") ||
            (`dpkg-query -s \"#{pkg}\" 2>/dev/null`.strip =~ /Architecture: (#{pkg_arch}|all)/)
        end

        def available?(pkg)
          apt_cache.include?(pkg)
        end

        protected

        def apt_cmd(cmd)
          "DEBIAN_FRONTEND=noninteractive apt-get -q -o=Dpkg::Use-Pty=0 #{cmd}"
        end

        def get_install_command(*pkgs)
          apt_cmd("install -y #{pkgs.flatten.join(' ')}")
        end

        def get_uninstall_command(*pkgs)
          apt_cmd("remove -y #{pkgs.flatten.join(' ')}")
        end

        def update_pkgs
          system(auth_cmd(apt_cmd('update')))
        end

        def apt_cache
          unless @apt_cache
            update_pkgs
            @apt_cache = `apt-cache pkgnames`.chomp.split("\n").collect { |s| s.strip }
          end
          @apt_cache
        end

        def pkg_arch
          @pkg_arch ||= `dpkg --print-architecture`.strip
        end

      end

      class Dnf < NixManager

        def installed?(pkg)
          if @distro[:release] >= '41'
            # dnf v5
            system("dnf list --installed #{pkg} >/dev/null 2>&1")
          else
            # dnf <= v4
            system("dnf list installed #{pkg} >/dev/null 2>&1")
          end
        end

        def available?(pkg)
          !!(`dnf repoquery --info #{pkg} 2>/dev/null`.strip =~ /Name\s*:\s*#{pkg}/)
        end

        protected

        def dnf_cmd(cmd)
          "dnf #{cmd}"
        end

        def get_install_command(*pkgs)
          dnf_cmd("install -y #{pkgs.flatten.join(' ')}")
        end

        def get_uninstall_command(*pkgs)
          dnf_cmd("remove -y #{pkgs.flatten.join(' ')}")
        end

      end

      class Zypper < NixManager

        def installed?(pkg)
          system("rpm -q --whatprovides #{pkg} >/dev/null 2>&1")
        end

        def available?(pkg)
          system("zypper -x -t package #{pkg} >/dev/null 2>&1")
        end

        protected

        def zypper_cmd(cmd)
          "zypper -t -i #{cmd}"
        end

        def get_install_command(*pkgs)
          zypper_cmd("install -y #{pkgs.flatten.join(' ')}")
        end

        def get_uninstall_command(*pkgs)
          zypper_cmd("remove -y #{pkgs.flatten.join(' ')}")
        end

      end

      class Pacman < NixManager

        def installed?(pkg)
          system("pacman -Qq #{pkg} >/dev/null 2>&1")
        end

        def available?(pkg)
          system(%Q[pacman -Ss "^#{pkg}$" >/dev/null 2>&1])
        end

        protected

        def pacman_cmd(cmd)
          "pacman --noconfirm #{cmd}"
        end

        def get_install_command(*pkgs)
          pacman_cmd("-S --needed #{ pkgs.join(' ') }")
        end

        def get_uninstall_command(*pkgs)
          pacman_cmd("-Rsu #{pkgs.flatten.join(' ')}")
        end

      end

    end

  end

  self.sniffers[:linux] = Sniffer::Linux

end
