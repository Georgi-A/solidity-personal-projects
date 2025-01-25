
const express = require("express");
const bodyParser = require("body-parser");

const app = express();

const morpho = require("./routes/morpho");
const ethena = require("./routes/ethena");
const mountain = require("./routes/mountain");
const spark = require("./routes/spark");

app.use(bodyParser.urlencoded({ extended: false }));

app.use("/dashboard", morpho);
app.use("/dashboard", ethena);
app.use("/dashboard", mountain);
app.use("/dashboard", spark);

app.use((req, res) => {
  res.status(404).send("<h1>Page not found</h1>");
});

// Start the server (no need for a separate server variable)
app.listen(3000, () => {
  console.log("Server is running on port 3000");
});
