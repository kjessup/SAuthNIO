FROM sauthnio_base:latest
COPY SAuthNIO /root/SAuthNIO
COPY templates /root/templates
COPY webroot /root/webroot
COPY config /root/config
WORKDIR /root
ENTRYPOINT /root/SAuthNIO