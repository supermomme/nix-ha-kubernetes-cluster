{ pkgs }: let 
  caConfig = pkgs.writeText "ca-config.json" ''
    {
      "signing": {
        "profiles": {
          "client": {
            "expiry": "87600h",
            "usages": ["signing", "key encipherment", "client auth"]
          },
          "peer": {
            "expiry": "87600h",
            "usages": ["signing", "key encipherment", "client auth", "server auth"]
          },
          "server": {
            "expiry": "87600h",
            "usages": ["signing", "key encipherment", "client auth", "server auth"]
          }
        }
      }
    }
  '';
in ''
  set -e

  # Generates a CA, if one does not exist, in the current directory.
  function genCa() {
    csrjson=$1
    [ -n "$csrjson" ] || { echo "Usage: genCa CSRJSON" && return 1; }
    [ -f ca.pem ] && { echo "$(realpath ca.pem) exists, not replacing the CA" && return 0; }
    ${pkgs.cfssl}/bin/cfssl gencert -loglevel 2 -initca "$csrjson" | ${pkgs.cfssl}/bin/cfssljson -bare ca
  }

  # Generates a certificate signed by ca.pem from the current directory
  # (convention over configuration).
  function genCert() {
    profile=$1
    output=$2 # e.g. `apiserver/client` will result in `apiserver/client.pem` and `apiserver/client-key.pem`
    csrjson=$3

    { [ -n "$profile" ] && [ -n "$output" ] && [ -n "$csrjson" ]; } \
        || { echo "Usage: genCert PROFILE OUTPUT CSRJSON" && return 1; }

    ${pkgs.cfssl}/bin/cfssl gencert \
        -loglevel 2 \
        -ca ca.pem \
        -ca-key ca-key.pem \
        -config ${caConfig} \
        -profile "$profile" \
        "$csrjson" \
        | ${pkgs.cfssl}/bin/cfssljson -bare "$output"
  }
'' 