# SAuth
wip

```
~~ssh-keygen -t rsa -b 4096 -f jwtRS256.key && \~~
~~  openssl rsa -in jwtRS256.key -pubout -outform PEM -out jwtRS256.key.pub~~
```

openssl genrsa -out private.pem 4096
openssl rsa -in private.pem -outform PEM -pubout -out public.pem
