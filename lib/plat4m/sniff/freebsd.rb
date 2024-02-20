# Copyright (c) 2023 M.J.N. Corino, The Netherlands
#
# This software is released under the MIT license.
#
# Plat4m Freebsd sniffer


module Plat4m

  module Sniffer

    module Freebsd

      class << self

        def detect_system
          # determine system platform
          System.new(System::Platform.new(arch: get_arch, cpus: get_cpu_count),
                     System::OS.new(id: :freebsd, **get_distro))
        end

        private

        def get_arch
          arch, _ = RbConfig::CONFIG['arch'].split('-')
          arch = 'x86' if arch =~ /i\d86/
          arch
        end

        def get_cpu_count
          (system('command -v nproc > /dev/null 2>&1') ? `nproc` : `getconf NPROCESSORS_ONLN`).to_i
        end

        def get_distro
          distro = {
            distro: 'freebsd'
          }
          distro[:release] = 0
          distro[:pkgman] = nil
          distro
        end

      end

    end

  end

  self.sniffers[:freebsd] = Sniffer::Freebsd

end
