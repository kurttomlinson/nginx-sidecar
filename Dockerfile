FROM nginx:1.15-alpine

COPY nginx.conf /etc/nginx/nginx.conf

ENV APP_CONTAINER_NAME app
ENV APP_IMAGE_PORT 3000

CMD sh -c "sed -i \"s/APP_CONTAINER_NAME/$APP_CONTAINER_NAME/g\" /etc/nginx/nginx.conf && \
            sed -i \"s/APP_IMAGE_PORT/$APP_IMAGE_PORT/g\" /etc/nginx/nginx.conf && \
            nginx -g 'daemon off;'"
