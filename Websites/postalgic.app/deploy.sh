aws s3 cp ./website s3://postalgic.app --recursive --profile personal
aws cloudfront create-invalidation --distribution-id EEVXA2K0D52DA --paths "/*" --profile personal