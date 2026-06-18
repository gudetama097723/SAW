require "openssl"
require "securerandom"

class User < ApplicationRecord
  has_one :player, dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validate :password_required_for_new_record

  attr_accessor :password

  before_validation :normalize_username

  def password=(raw_password)
    @password = raw_password
    self.password_digest = self.class.digest(raw_password) if raw_password.present?
  end

  def authenticate(raw_password)
    return false if password_digest.blank? || raw_password.blank?

    salt, stored_hash = password_digest.split("$", 2)
    return false unless salt && stored_hash

    candidate = self.class.hash_password(raw_password, salt)
    secure_compare(stored_hash, candidate) && self
  end

  def self.digest(raw_password)
    salt = SecureRandom.hex(16)
    "#{salt}$#{hash_password(raw_password, salt)}"
  end

  def self.hash_password(raw_password, salt)
    OpenSSL::PKCS5.pbkdf2_hmac(raw_password, salt, 60_000, 32, "SHA256").unpack1("H*")
  end

  private

  def normalize_username
    self.username = username.to_s.strip.downcase
  end

  def password_required_for_new_record
    errors.add(:password, "を入力してください") if new_record? && password.blank?
  end

  def secure_compare(a, b)
    return false unless a.bytesize == b.bytesize

    ActiveSupport::SecurityUtils.secure_compare(a, b)
  end
end
