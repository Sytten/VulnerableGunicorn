from flask import Flask, request, jsonify

app = Flask(__name__)
app.debug = True


@app.route('/', methods=['GET', 'POST'])
def main():
    # the next line is required for Transfer-Encoding support in the request
    request.environ['wsgi.input_terminated'] = True
    headers = {}
    for header in request.headers:
        headers[header[0]] = header[1]
    return jsonify(headers=headers)


if __name__ == "__main__":
    app.run(debug=True, use_debugger=False, use_reloader=False, passthrough_errors=True)
