This repository is unaudited but has very high code coverage. Use at your own risk.

## catERC20

This is an optimised implementation of xERC20 (or ERC-7281). It is inspired by the https://github.com/defi-wonderland/xERC20.

### Improvements

- Burns are subtracted from mint limit.
- Lockbox is set as a bridge rather than as a lockbox while being fully compatible with ERC-7281. 
- Burns are unlimited. The burn limit serves no protection since Bridge could collect tokens from users anyway.
- Single slot bridge config, with major gas improvements.

### Minor Differences

- No Factory ownership on contract.
- Simplified limit logic for easier auditing.

## Development

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### coverage

```shell
$ forge coverage
```

```