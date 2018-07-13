# Create a docker image suitable for running the example
FROM gcr.io/kubeflow-images-public/tensorflow-1.6.0-notebook-cpu:v0.2.1
USER root
RUN pip install --no-cache-dir annoy ktext nltk pydot
USER jovyan