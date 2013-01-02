require 'puppet/settings/string_setting'

# A file.
class Puppet::Settings::FileSetting < Puppet::Settings::StringSetting
  class SettingError < StandardError; end

  # An unspecified user or group
  # @api private
  class Unspecified
    def value
      nil
    end
  end

  # A "root" user or group
  # @api private
  class Root
    def value
      "root"
    end
  end

  # A "service" user or group, which means to use
  # the value in settings, if it is safe to do so.
  # @api private
  class Service
    def initialize(name, fallback, settings, available_method)
      @settings = settings
      @available_method = available_method
      @name = name
      @fallback = fallback
    end

    def value
      if safe_to_use_settings_value?
        @settings[@name]
      else
        @fallback
      end
    end

  private
    def safe_to_use_settings_value?
      @settings[:mkusers] or @settings.send(@available_method)
    end
  end

  attr_accessor :mode, :create

  def initialize(args)
    @group = Unspecified.new
    @owner = Unspecified.new
    super(args)
  end

  # Should we create files, rather than just directories?
  def create_files?
    create
  end

  def group=(value)
    @group = case value
             when "root"
               Root.new
             when "service"
               Service.new(:group, nil, @settings, :service_group_available?)
             else
               unknown_value(':group', value)
             end
  end

  def owner=(value)
    @owner = case value
             when "root"
               Root.new
             when "service"
               Service.new(:user, "root", @settings, :service_user_available?)
             else
               unknown_value(':owner', value)
             end
  end

  def group
    @group.value
  end

  def owner
    @owner.value
  end

  def munge(value)
    if value.is_a?(String)
      value = File.expand_path(value)
    end
    value
  end

  def type
    :file
  end

  # Turn our setting thing into a Puppet::Resource instance.
  def to_resource
    return nil unless type = self.type

    path = self.value

    return nil unless path.is_a?(String)

    # Make sure the paths are fully qualified.
    path = File.expand_path(path)

    return nil unless type == :directory or create_files? or File.exist?(path)
    return nil if path =~ /^\/dev/ or path =~ /^[A-Z]:\/dev/i

    resource = Puppet::Resource.new(:file, path)

    if Puppet[:manage_internal_file_permissions]
      if self.mode
        # This ends up mimicking the munge method of the mode
        # parameter to make sure that we're always passing the string
        # version of the octal number.  If we were setting the
        # 'should' value for mode rather than the 'is', then the munge
        # method would be called for us automatically.  Normally, one
        # wouldn't need to call the munge method manually, since
        # 'should' gets set by the provider and it should be able to
        # provide the data in the appropriate format.
        mode = self.mode
        mode = mode.to_i(8) if mode.is_a?(String)
        mode = mode.to_s(8)
        resource[:mode] = mode
      end

      # REMIND fails on Windows because chown/chgrp functionality not supported yet
      if Puppet.features.root? and !Puppet.features.microsoft_windows?
        resource[:owner] = self.owner if self.owner
        resource[:group] = self.group if self.group
      end
    end

    resource[:ensure] = type
    resource[:loglevel] = :debug
    resource[:links] = :follow
    resource[:backup] = false

    resource.tag(self.section, self.name, "settings")

    resource
  end

  # Make sure any provided variables look up to something.
  def validate(value)
    return true unless value.is_a? String
    value.scan(/\$(\w+)/) { |name|
      name = $1
      unless @settings.include?(name)
        raise ArgumentError,
          "Settings parameter '#{name}' is undefined"
      end
    }
  end

private
  def unknown_value(parameter, value)
    raise SettingError, "The #{parameter} parameter for the setting '#{name}' must be either 'root' or 'service', not '#{value}'"
  end
end
