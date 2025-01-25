// routes/dashboard.js
const express = require("express");
const router = express.Router();
const { ApolloClient, InMemoryCache, gql } = require("@apollo/client");

router.get("/morpho", async (req, res) => {
  try {
    const endpoint = "https://blue-api.morpho.org/graphql";

    const client = new ApolloClient({
      uri: endpoint,
      cache: new InMemoryCache(),
    });

    const query = gql`
      query {
        USDC_Vault: vaultByAddress(address: "0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB") {
          name
          dailyApys {
            apy
            netApy
          }
        }
        USDT_Vault: vaultByAddress(address: "0xbEef047a543E45807105E51A8BBEFCc5950fcfBa") {
          name
          dailyApys {
            apy
            netApy
          }
        }
      }
    `;

    const { data } = await client.query({ query });

    console.log(data);
    res.json({ data });

  } catch (error) {
    console.error("Error fetching: ", error);
    res.status(500).json({ error: "Failed to fetch data" });
  }
});

module.exports = router;
