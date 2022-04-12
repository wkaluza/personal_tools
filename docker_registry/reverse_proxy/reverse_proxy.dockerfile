FROM nginx:1.20.2

RUN rm -rf \
/etc/nginx/nginx.conf \
/etc/nginx/conf.d/
RUN mkdir /etc/nginx/conf.d

COPY ./nginx.conf \
/etc/nginx/
COPY ./servers/*.conf \
/etc/nginx/conf.d/

RUN chmod --recursive 400 \
/etc/nginx/
