SELECT
    client_id,
    schema_decode('parse_linde', encoded_data) as decoded_data
FROM
    "message.publish"
WHERE
    topic =~ 'device/#'