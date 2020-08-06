FROM php:7.4.7

RUN additionalPackages=" \
    apt-transport-https \
    git \
    openssh-client \
    rsync \
    libaio1 \ 
    " \
    buildDeps=" \
    freetds-dev \
    libfreetype6-dev \
    " \
    && runDeps=" \
    libmcrypt4 \
    firebird-dev \
    openssh-client \
    libzip-dev \
    rsync \
    " \
    && phpModules=" \
    mysqli \
    pdo_mysql \
    pdo_firebird \
    zip \
    " \
    && echo "deb http://security.debian.org/ stretch/updates main contrib non-free" > /etc/apt/sources.list.d/additional.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends $additionalPackages $buildDeps $runDeps \
    && docker-php-source extract \
    && cd /usr/src/php/ext/ \
    && docker-php-ext-install $phpModules \
    && printf "\n" \
    && for ext in $phpModules; do \
    rm -f /usr/local/etc/php/conf.d/docker-php-ext-$ext.ini; \
    done \
    && docker-php-source delete \
    && docker-php-ext-enable $phpModules

RUN pear config-set http_proxy $HTTP_PROXY \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug

# Install composer and prestissimo plugin and put binary into $PATH
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/composer.phar /usr/local/bin/composer \
    && composer global require hirak/prestissimo

# Install testing tools
RUN composer global require phpunit/phpunit phpmd/phpmd squizlabs/php_codesniffer \
    && composer global require phpstan/phpstan  vimeo/psalm  phan/phan  deployer/deployer  deployer/recipes 

# Install Node.js & Yarn
RUN apt-get install -y unzip nodejs bsdtar build-essential npm  \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# install oci
COPY ./oracle-sdk/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip \
    ./oracle-sdk/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip \
    ./oracle-sdk/instantclient-sqlplus-linux.x64-19.6.0.0.0dbru.zip /tmp/

RUN unzip /tmp/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip -d /usr/local/  \
    && unzip /tmp/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip -d /usr/local/ \
    && unzip /tmp/instantclient-sqlplus-linux.x64-19.6.0.0.0dbru.zip -d /usr/local/ \
    && rm -rf /tmp/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip \
    && rm -rf /tmp/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip \
    && rm -rf /tmp/instantclient-sqlplus-linux.x64-19.6.0.0.0dbru.zip \
    && ln -s /usr/local/instantclient_19_6 /usr/local/instantclient \
    && ln -s /usr/local/instantclient/lib* /usr/lib \
    && ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus

RUN echo 'instantclient,/usr/local/instantclient/' | pecl install oci8 \
    && docker-php-ext-enable oci8 \
    && docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/usr/local/instantclient \
    && docker-php-ext-install pdo_oci \
    && export LD_LIBRARY_PATH=/usr/local/instantclient/


COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php", "-a"]