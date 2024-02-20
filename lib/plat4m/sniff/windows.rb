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
            distro: 'windows'
          }
          # the 'ver' command returns something like "Microsoft Windows [Version xx.xx.xx.xx]"
          match = `ver`.strip.match(/\[(.*)\]/)
          ver = match[1].split.last
          distro[:release] = ver.split('.').shift
          distro[:version] = ver
          distro[:pkgman] = nil
          distro
        end

      end

    end

  end

  self.sniffers[:windows] = Sniffer::Darwin

end
