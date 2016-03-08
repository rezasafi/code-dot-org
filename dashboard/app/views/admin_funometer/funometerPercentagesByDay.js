/* globals percentagesByDay */

// Load the Visualization API and the appropriate packages, setting a callback
// to run when the API is loaded.
google.load('visualization', '1.0', {'packages':['corechart']});
google.setOnLoadCallback(drawChart);

// The callback that creates and populates the data table, instantiates the
// chart, and draws it.
function drawChart() {
  var data = new google.visualization.DataTable();
  data.addColumn('string', 'Date');
  data.addColumn('number', 'Percentage');
  data.addRows(percentagesByDay);

  // Instantiate and draw our chart, passing in some options.
  var options = {'title': 'Fun-O-Meter By Day', 'width': 800, 'height': 500};
  var chart = new google.visualization.LineChart(document.getElementById('chart-by-day'));
  chart.draw(data, options);
}
