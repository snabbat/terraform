FROM codercom/enterprise-base:ubuntu

USER root

# Install Java 17 (required by PySpark driver)
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends openjdk-17-jdk-headless && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Pre-download Spark JARs
ENV JARS_DIR=/opt/spark/jars
RUN mkdir -p $JARS_DIR && \
    MAVEN=https://repo1.maven.org/maven2 && \
    curl -fsSL "$MAVEN/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.6.1/iceberg-spark-runtime-3.5_2.12-1.6.1.jar" \
         -o "$JARS_DIR/iceberg-spark-runtime-3.5_2.12-1.6.1.jar" && \
    curl -fsSL "$MAVEN/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" \
         -o "$JARS_DIR/hadoop-aws-3.3.4.jar" && \
    curl -fsSL "$MAVEN/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" \
         -o "$JARS_DIR/aws-java-sdk-bundle-1.12.262.jar" && \
    curl -fsSL "$MAVEN/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" \
         -o "$JARS_DIR/postgresql-42.7.3.jar"

USER coder
