require "openssl"
require "digest/sha256"
require "base64"

module Turnir::Webserver::Utils
  extend self

  @@KICK_PUBLIC_KEY = <<-PEM
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq/+l1WnlRrGSolDMA+A8
6rAhMbQGmQ2SapVcGM3zq8ANXjnhDWocMqfWcTd95btDydITa10kDvHzw9WQOqp2
MZI7ZyrfzJuz5nhTPCiJwTwnEtWft7nV14BYRDHvlfqPUaZ+1KR4OCaO/wWIk/rQ
L/TjY0M70gse8rlBkbo2a8rKhu69RQTRsoaf4DVhDPEeSeI5jVrRDGAMGL3cGuyY
6CLKGdjVEM78g3JfYOvDU/RvfqD7L89TZ3iN94jrmWdGz34JNlEI5hqK8dd7C5EF
BEbZ5jgB8s8ReQV8H+MkuffjdAj3ajDDX3DOJMIut1lBrUVD1AaSrGCKHooWoL2e
twIDAQAB
-----END PUBLIC KEY-----
PEM

  # @@public_key = OpenSSL::PKey::RSA.new(@@KICK_PUBLIC_KEY)
  @@digest = OpenSSL::Digest.new("SHA256")

  def verify_kick_signature(body, kick_signature) : Bool
    signature = Base64.decode_string(kick_signature)
    digest = Digest::SHA256.digest(body)

    true
    # @@public_key.verify(@@digest, signature, digest)
  end
end
