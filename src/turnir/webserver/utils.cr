require "base64"
require "process"

module Turnir::Webserver::Utils
  extend self

  KICK_PUBLIC_KEY = <<-PEM
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

  def log(msg : String)
    print "[Kick Signature] "
    puts msg
  end

  def verify_kick_signature(message : String, kick_signature : String) : Bool
    escaped_signed_message = message.gsub("'", "'\\''")
    escaped_signature_b64 = kick_signature.gsub("'", "'\\''")

    # Build the shell command
    command = <<-CMD
      openssl dgst -sha256 -verify <(echo '#{KICK_PUBLIC_KEY}') \\
        -signature <(echo '#{escaped_signature_b64}' | base64 -d) \\
        <(echo -n '#{escaped_signed_message}')
    CMD

    output = IO::Memory.new
    status = Process.run("bash", args: ["-c", command], output: output, shell: true)
    output_s = output.to_s

    # Check the result
    if status.success? && output_s.includes?("Verified OK")
      # log "Signature is valid."
      true
    else
      log "Signature verification failed:"
      log "Msg: #{message}"
      log "Signature: #{kick_signature}"
      log "Output: #{output_s}"
      false
    end
  end
end
