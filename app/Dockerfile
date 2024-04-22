FROM python:3.11.4
WORKDIR /code
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt
RUN apt-get update
RUN apt-get install ffmpeg libsm6 libxext6  -y
COPY ./model.py /code/model.py
COPY ./main.py /code/main.py
COPY ./model /code/model
EXPOSE 5000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]