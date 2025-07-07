# licredity-v1-oracle

Licredity Oracle is a modular oracle system that supports the following functions:

1. Read data from Uniswap V4 Pool and calculate the average price using the EMA algorithm
1. Calculate the value of input tokens by reading Chainlink oracle data
1. Calculate the value of LP NFTs managed by Uniswap V4 Position Manager

## EMA Price

We used the following EMA price algorithm to calculate the average price:

$$
\begin{gather}
\alpha = e^{\text{power}} \\
\text{power} = \frac{\text{lastUpdateTimeStamp} - \text{block.timestamp}}{600} \\
\text{EMA} = \alpha \cdot \text{pirce} \times (1 - \alpha) \cdot \text{lastPirce}
\end{gather}	
$$

Note: To avoid price manipulation, the `price` used here is limited to the range of 0.015625 above and below `lastPrice`
