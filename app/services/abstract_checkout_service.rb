# frozen_string_literal: true

class AbstractCheckoutService < BaseService
  class InvalidAlgorithmError < StandardError; end
  class InvalidPrivateKeyError < StandardError; end
  class InvalidTTLError < StandardError; end

  ENCRYPT_ALGORITHM = 'aes-256-cbc'
  ENCODE_ALGORITHM  = 'base64'

  def initialize(private_key:, algorithm:, encrypt:, ttl:, include:)
    raise InvalidPrivateKeyError, 'private key is missing' unless
      private_key.present?

    raise InvalidAlgorithmError, 'algorithm is missing' unless
      algorithm.present?

    raise InvalidTTLError, 'must be greater than or equal to 3600 (1 hour)' if
      ttl.present? && ttl < 1.hour

    @renderer    = Keygen::JSONAPI::Renderer.new(context: :checkout)
    @private_key = private_key
    @algorithm   = algorithm
    @encrypted   = encrypt
    @ttl         = ttl
    @includes    = include
  end

  def call
    raise NotImplementedError, '#call must be implemented by a subclass'
  end

  private

  attr_reader :renderer,
              :private_key,
              :algorithm,
              :encrypted,
              :ttl,
              :includes

  def encrypted?
    !!encrypted
  end

  def encoded?
    !encrypted?
  end

  def ttl?
    ttl.present?
  end

  def encrypt(value, secret:)
    Keygen.logger.debug { "encrypting=#{value}" }

    aes = OpenSSL::Cipher.new(ENCRYPT_ALGORITHM)
    aes.encrypt

    key = OpenSSL::Digest::SHA256.digest(secret)
    iv  = aes.random_iv

    aes.key = key
    aes.iv  = iv

    ciphertext = aes.update(value) + aes.final

    [ciphertext, iv].map { encode(_1, strict: true) }
                    .join('.')
                    .chomp
  end

  def encode(value, strict: false)
    Keygen.logger.debug { "encoding=#{value} strict=#{strict}" }

    enc = if strict
            Base64.strict_encode64(value)
          else
            Base64.encode64(value)
          end

    enc.chomp
  end

  def sign(value, prefix:)
    Keygen.logger.debug { "signing=#{value} prefix=#{prefix}" }

    data = "#{prefix}/#{value}"

    case algorithm
    when 'rsa-pss-sha256'
      pkey = OpenSSL::PKey::RSA.new(private_key)
      sig  = pkey.sign_pss(OpenSSL::Digest::SHA256.new, data, salt_length: :max, mgf1_hash: 'SHA256')
    when 'rsa-sha256'
      pkey = OpenSSL::PKey::RSA.new(private_key)
      sig = pkey.sign(OpenSSL::Digest::SHA256.new, data)
    when 'ed25519'
      pkey = Ed25519::SigningKey.new([private_key].pack('H*'))
      sig  = pkey.sign(data)
    else
      raise InvalidAlgorithmError, 'signing scheme is not supported'
    end

    encode(sig, strict: true)
  end
end