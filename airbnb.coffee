request = require 'request'

BASE_URL = "https://www.airbnb.com/search/ajax_get_results"

# ?search_view=1&min_bedrooms=0&min_bathrooms=0&min_beds=0&page=1&location=Raleign%2C+NC&checkin=05%2F01%2F2013&checkout=05%2F12%2F2013&guests=1&sort=0&keywords=&price_min=&price_max=&per_page=21

express = require 'express'

mongojs = require 'mongojs'

mongo = mongojs "mongodb://127.0.0.1:27017/airbnb", ['properties']

mongo.properties.ensureIndex { available_dates: 1 }

moment = require 'moment'
async = require 'async'
_ = require 'underscore'

app = express()
app.use express.bodyParser()
app.use express.methodOverride()

app.use app.router


template = (body) ->'
<html>
  <head>
    <title>AirBNB</title>
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/2.3.0/css/bootstrap.min.css">
    <link href="//www.eyecon.ro/bootstrap-datepicker/css/datepicker.css" rel="stylesheet">
  </head>

  <body>
    <div class="container">
      <form class="form-horizontal" method="post">
        <div class="form-group">
        <label for="location">Location</label>
        <input type="text" class="form-control" id="location" placeholder="Enter location" name="location">
      </div>
      <div class="form-group">
        <label for="from">From</label>
        <div class="input-append date" id="from" data-date="12-11-2013" data-date-format="dd-mm-yyyy">
          <input class="span2" size="16" type="text" value="12-11-2013" readonly name="from">
          <span class="add-on"><i class="icon-calendar"></i></span>
        </div>
      </div>
      <div class="form-group">
        <label for="to">TO</label>
        <div class="input-append date" id="to" data-date="12-11-2013" data-date-format="dd-mm-yyyy">
          <input class="span2" size="16" type="text" value="12-11-2013" readonly name="to">
          <span class="add-on"><i class="icon-calendar"></i></span>
        </div>
      </div>
      <div class="checkbox">
        <label>
          <input type="checkbox" name="onlyavailable"> Show only available
        </label>
      </div>
      <button type="submit" class="btn btn-default">Submit</button>
      </form>
    </div>
  <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/2.0.3/jquery.min.js"></script>
  <script src="//cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.2.0/js/bootstrap-datepicker.min.js"></script>
  <script>
    $(document).ready(function(){
      var options = { format: "mm-dd-yyyy" };
      $("#from").datepicker(options);
      $("#to").datepicker(options);
    });
  </script>
  </body>
</html>
'

templ = """
  {% if date in b.available_dates %}
    <td> </td>
  {% else %}
    <td> X </td>
  {% endif %}
"""

__buildTable = (body, dates, cb) ->
  tr = []
  th = ''


  async.each body, (b, callback) ->
    td = ""
    async.each dates, (date, cb) ->
      th += "<th>#{date}</th>"
      if date in b.available_dates
        td += "<td>-</td>"
      else
        td += "<td>X</td>"
      tr +="<tr><td>#{b.name}</td>#{td}</tr>"
      cb()
    ,(err) ->
      callback()
  , (err) ->
    return cb __baseHtml "<table class='table'><tr><th></th>#{th}</tr>#{tr}</table>"

__baseHtml = (body) ->
  """
  <html>
  <head>
    <title>AirBNB</title>
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/2.3.0/css/bootstrap.min.css">
    <link href="//www.eyecon.ro/bootstrap-datepicker/css/datepicker.css" rel="stylesheet">
  </head>

  <body>
    <div class="container">
      #{body}
    </div>
  </body>
  </html>

"""

__processData = (body, location, from, cb) ->
  console.log 'body'
  properties = body?.properties
  props = {}
  # mongo.properties.insert properties, cb
  async.each properties, (prop, callback) ->
    mongo.properties.update { _id: prop.id }, { $set: {name: prop.name, location: location}, $addToSet: { available_dates: from }}, { upsert: true }, callback

  , cb


app.get '/', (req, res) ->
  res.send template(null)

app.post '/', (req, res) ->

  location = req.body.location
  from     = req.body.from
  to       = req.body.to

  start = moment(from).date()
  end = moment(to).date()

  data = {}

  i = 0

  dates = []
  async.whilst ->
    return end > start
  , (callback) ->
    dates.push from
    startDate = from
    y = if i is 0 then i else 1
    endDate = moment(startDate, 'MM-DD-YYYY').add('days', y).format('MM-DD-YYYY')
    from = endDate
    start++
    i++
    opts =
      url: BASE_URL
      qs:
        location : location
        checkin  : startDate
        checkout : endDate
      json: true
    request opts, (e, r, body) ->
      __processData body, location, startDate, (e, d) ->
        callback()

  ,(err) ->
    mongo.properties.find { location: location }, (err, data) ->
      __buildTable data, dates, (dt) ->
        res.send dt

app.listen 8080