class RefinerySetting < ActiveRecord::Base

  validates_presence_of :name
  validates_uniqueness_of :name

  serialize :value # stores into YAML format
  after_save do |object|
    cache_write(object.name, object.value)
  end

  def self.cache_write(name, value)
    Rails.cache.write("refinery_setting_#{name}", value)
  end

  def self.cache_read(name)
    Rails.cache.read("refinery_setting_#{name}")
  end

  # Number of settings to show per page when using will_paginate
  def self.per_page
    10
  end

  # prettier version of the name.
  # site_name becomes Site Name
  def title
    self.name.titleize
  end

  # Access method that allows dot notation to work.
  # Say you had a setting called "site_name". You could access that by going RefinerySetting[:site_name]
  # but with this you can also access that by going RefinerySettting.site_name
  def self.method_missing(method, *args)
    method_name = method.to_s
    super(method, *args)

  rescue NoMethodError
    if method_name =~ /=$/
      self[method_name.gsub('=', '')] = args.first
    else
      self[method_name]
    end
  end

  def self.find_or_set(name, the_value)
    # Try to get the value from cache first.
    unless (value = cache_read(name)).present?
      # Either find the record or create one with the defined value
      value = find_or_create_by_name(:name => name.to_s, :value => the_value).value
      # Cache it
      cache_write(name, value)
    end

    # Return what we found.
    value
  end

  def self.[](name)
    # Try to get the value from cache first.
    unless (value = cache_read(name)).present?
      # Not found in cache, try to find the record
      value = if (setting = self.find_by_name(name.to_s)).present?
        # Cache it
        cache_write(name, setting.value)
      else
        # Still cache the nil to prevent more lookups to find nothing.
        cache_write(name, nil)
      end
    end

    # Return what we found.
    value
  end

  def self.[]=(name, value)
    setting = find_or_create_by_name(name.to_s)
    setting.value = value
    setting.save!
  end

  # Below is not very nice, but seems to be required
  # The problem is when Rails serialises a fields like booleans
  # it doesn't retreieve it back out as a boolean
  # it just returns a string. This code maps the two boolean
  # values correctly so a boolean is returned
  REPLACEMENTS = {"true" => true, "false" => false}

  def value
    current_value = self[:value]

    if current_value.present?
      # This bit handles true and false so that true and false are actually returned
      # not "0" and "1"
      REPLACEMENTS.each do |current, new_value|
        current_value = new_value if current_value == current
      end

      # converts the serialised value back to an integer
      # if the value is an integer
      begin
        if current_value.to_i.to_s == current_value
          current_value = current_value.to_i
        end
      rescue
        current_value
      end
    end

    return current_value
  end

  def value=(new_value)
    # must convert to string if true or false supplied otherwise it becomes 0 or 1, unfortunately.
    new_value = new_value.to_s if ["trueclass","falseclass"].include?(new_value.class.to_s.downcase)
    self[:value] = new_value
  end

end