# Copyright (c) 2023 M.J.N. Corino, The Netherlands
#
# This software is released under the MIT license.
#
# Plat4m PkgManager


module Plat4m

  class PkgManager

    def initialize
      @has_sudo = false
    end

    def installed?(pkg)
      raise NoMethodError
    end

    def select_uninstalled(*pkgs)
      pkgs.flatten.select { |pkg| !installed?(pkg) }
    end

    def available?(pkg)
      raise NoMethodError
    end

    def select_available(*pkgs)
      pkgs.flatten.select { |pkg| available?(pkg) }
    end

    def make_install_command(*pkgs)
      raise NoMethodError
    end

    def install(*pkgs, silent: false)
      cmd = make_install_command
      silent ? system("#{cmd} >/dev/null 2>&1") : system(cmd)
    end

    def make_uninstall_command(*pkgs)
      raise NoMethodError
    end

    def uninstall(*pkgs, silent: false)
      cmd = make_uninstall_command
      silent ? system("#{cmd} >/dev/null 2>&1") : system(cmd)
    end

    def is_root?
      false
    end

    def has_sudo?
      @has_sudo
    end

  end

end
