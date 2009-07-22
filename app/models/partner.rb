class Partner < ActiveRecord::Base
  acts_as_authentic

  belongs_to :state, :class_name => "GeoState"

  before_validation :reformat_phone

  validates_presence_of :name
  validates_presence_of :url
  validates_presence_of :address
  validates_presence_of :city
  validates_presence_of :state_id
  validates_presence_of :zip_code
  validates_format_of :zip_code, :with => /^\d{5}(-\d{4})?$/
  validates_presence_of :phone
  validates_format_of :phone, :with => /^\d{3}-\d{3}-\d{4}$/, :message => 'Phone must look like ###-###-####'

  def self.find_by_login(login)
    find_by_username(login) || find_by_email(login)
  end

  def self.default_id
    1
  end

  def state_abbrev=(abbrev)
    self.state = GeoState[abbrev]
  end

  def state_abbrev
    state && state.abbreviation
  end

  def reformat_phone
    digits = phone.gsub(/\D/,'')
    if digits.length == 10
      self.phone = [digits[0..2], digits[3..5], digits[6..9]].join('-')
    end
  end

end
