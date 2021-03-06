class CertSigningRequest < ApplicationRecord
  attr_accessor :subject_password

  belongs_to :subject, polymorphic: true
  belongs_to :subject_key, class_name: "CryptoKey"
  belongs_to :profile, class_name: "CertProfile"
  belongs_to :certificate, required: false
  has_and_belongs_to_many :issuers, class_name: "Authority",
    join_table: "authorities_csr",
    foreign_key: "csr_id",
    association_foreign_key: "authority_id"

  validates :name, presence: true, length: { minimum: 5 }
  validates :subject_pubid, presence: true
  validates :profile_id, presence: true

  attr_accessor :issuer_password, :issuer_certificate_id, :validity_duration
  validates :issuer_password, presence: true, on: :accept
  validates :issuer_certificate_id, numericality: { only_integer: true }, on: :accept
  validates :validity_duration,
    numericality: { only_integer: true, greater_than: 0, less_than: 11 },
    presence: true,
    on: :accept

  def subject_pubid
    self.subject.try(:pubid)
  end

  def subject_pubid=(pubid)
    self.subject = ApplicationRecord.find_by_pubid(pubid, [User, Authority])
  end

  def authenticate
    self.subject.authenticate(self.subject_password)
  end

  def submit_req
    sign_key = self.subject.keys.find(self.subject_key_id)
    return nil unless sign_key

    req = OpenSSL::X509::Request.new
    req.version = 2
    req.subject = self.subject.x509 [["CN", self.name]]
    req.public_key = sign_key.public_key
    req.sign sign_key.get_private_key(self.subject_password), Rails.application.config.digest
    self.pem = req.to_pem
    req
  end

  def x509
    OpenSSL::X509::Request.new self.pem
  end
end
