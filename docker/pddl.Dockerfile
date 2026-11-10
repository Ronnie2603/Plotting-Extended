FROM eclipse-temurin:17-jdk-noble

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"
ENV PDDL_APP_ROOT=/app

ARG ENHSP_REF=enhsp-20
ARG FAST_DOWNWARD_REF=release-23.06.0
ARG SYMK_REF=c97ce836a
ARG VAL_REF=master

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    bash \
    python3 \
    build-essential \
    cmake \
    autoconf \
    automake \
    flex \
    bison \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/planners

RUN git clone --depth 1 --branch "$FAST_DOWNWARD_REF" https://github.com/aibasel/downward.git fast-downward \
    && cd fast-downward \
    && sed -i "1i import os\n" src/translate/axiom_rules.py \
    && sed -i "/with timers.timing(\"Computing negative axioms\"):/,+1c\    if os.environ.get(\"FD_DISABLE_NEGATIVE_AXIOMS\") in (\"1\", \"true\", \"yes\"):\n        print(\"Skipping negative axioms because FD_DISABLE_NEGATIVE_AXIOMS is set.\")\n    else:\n        with timers.timing(\"Computing negative axioms\"):\n            compute_negative_axioms(clusters)" src/translate/axiom_rules.py \
    && ./build.py release -j4 \
    && cp src/translate/axiom_rules.py builds/release/bin/translate/axiom_rules.py \
    && test -x builds/release/bin/downward

RUN git clone https://github.com/speckdavid/symk.git symk \
    && cd symk \
    && git checkout "$SYMK_REF" \
    && ./build.py release -j4 \
    && test -x builds/release/bin/downward

RUN git clone --depth 1 --branch "$VAL_REF" https://github.com/KCL-Planning/VAL.git VAL \
    && sed -i 's/VERSION 2.8/VERSION 3.5/' VAL/CMakeLists.txt \
    && cmake -S VAL -B VAL/build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build VAL/build --target Validate --parallel \
    && ln -s build/bin/Validate VAL/validate \
    && test -x VAL/validate

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt

RUN python3 -m pip install \
    --break-system-packages \
    --no-cache-dir \
    -r /tmp/requirements.txt

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'exec java ${JAVA_OPTS:-} -jar /opt/planners/enhsp/enhsp-dist/enhsp.jar "$@"' \
    > /usr/local/bin/enhsp \
    && chmod +x /usr/local/bin/enhsp \
    && ln -s /opt/planners/VAL/validate /usr/local/bin/validate \
    && ln -s /opt/planners/VAL/validate /usr/local/bin/Validate


RUN git clone --depth 1 --branch "$ENHSP_REF" https://github.com/hstairs/enhsp.git enhsp

COPY enhsp-heuristics/ENHSP.java /opt/planners/enhsp/src/planners/ENHSP.java

RUN cd enhsp \
    && chmod +x compile \
    && ./compile \
    && test -f enhsp-dist/enhsp.jar


WORKDIR /app

CMD ["sleep", "infinity"]