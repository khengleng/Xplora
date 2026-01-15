# DBA has NO access to encryption
path "transit/*" { capabilities = ["deny"] }
path "secret/data/xplora/keys/*" { capabilities = ["deny"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
