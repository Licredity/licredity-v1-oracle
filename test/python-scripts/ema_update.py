import mpmath as mp
import argparse

mp.dps = 100

def ema_price(last_price, now_sqrt_price, time_diff):
    alpha = mp.exp(-time_diff / mp.mpf(600))
    
    now_price = mp.power(now_sqrt_price, 2) / mp.power(2, 96)
    if (now_price > last_price * (1 + 0.015625)):
        now_price = last_price * (1 + 0.015625)
    elif (now_price < last_price * (1 - 0.015625)):
        now_price = last_price * (1 - 0.015625)
    
    new_price = alpha * now_price + (1 - alpha) * last_price
    return new_price / mp.power(2, 96) * mp.mpf(1e18)

def get_oralce_debt(ema_price, amount):
    return mp.mpf(amount) / mp.mpf(ema_price)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('last_price', type=int)
    parser.add_argument('now_sqrt_price', type=int)
    parser.add_argument('time_diff', type=int)
    # parser.add_argument('amount', type=int)
    args = parser.parse_args()
    
    last_price = mp.mpf(args.last_price)
    now_sqrt_price = mp.mpf(args.now_sqrt_price)

    ema_price = ema_price(last_price, now_sqrt_price, args.time_diff)
    # token_output = get_oralce_debt(ema_price, args.amount)
    print(int(ema_price), end="")