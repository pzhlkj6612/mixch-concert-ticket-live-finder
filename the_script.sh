#!/bin/bash


set -e
set -o pipefail
set -u


jq --version >/dev/stderr


offset_second="$1"
event_list_json="$2"

file "${event_list_json}" >/dev/stderr

now_second=$(date '+%s')
limit_second=$((${now_second} + ${offset_second}))


# collect live

declare -A live_timestamp_code_row_map

while read -r event_info; do
  id="$(jq --raw-output '.id' <<<"${event_info}")"
  name="$(jq --raw-output '.name' <<<"${event_info}")"
  thumbnail_url="$(jq --raw-output '.thumbnailUrl' <<<"${event_info}")"
  min_price="$(jq --raw-output '.minPrice' <<<"${event_info}")"
  close_timestamp="$(jq --raw-output '.liveCloseUnixTime' <<<"${event_info}")"
  archive="$(jq --raw-output '.archive' <<<"${event_info}")"

  echo "processing [${id}]" >/dev/stderr

  if [[ ${now_second} -gt ${close_timestamp} ]]; then
    echo -e '\t''ignored' >/dev/stderr
    continue
  fi

  close_datetime="$(date --date="@${close_timestamp}" '+%Y-%m-%d %H:%M:%S')"

  if [[ "${thumbnail_url}" != 'null' ]]; then
    thumbnail_element="<img alt=\"${name}\" src=\"${thumbnail_url}\" height=\"64px\">"
  else
    thumbnail_element='<i>no thumbnail</i>'
  fi;

  key="${id}"
  value="$(
    cat <<-TABLE_ROW
		  <tr>
		    <td>${close_datetime}</td>
		    <td>
		      <a href="https://mixch.tv/liveview/${id}/detail">${id}</a>
		      <br>
		      ${thumbnail_element}
		      <br>
		      ${name}
		    </td>
		    <td>${min_price}</td>
		    <td>${archive}</td>
		  </tr>
		TABLE_ROW
  )"
  live_timestamp_code_row_map["${key}"]="${value}"

  echo -e '\t''collected' >/dev/stderr

done < <(<"${event_list_json}" jq --compact-output '.liveviews | sort_by( .liveCloseUnixTime ) | .[]')

echo "count of incoming live = ${#live_timestamp_code_row_map[@]}" >/dev/stderr


# draw table

echo '<table>'

cat <<'TABLE_HEADER'
  <thead>
    <th>END (UTC)</th>
    <th>Thumbnail, URL & Title</th>
    <th>Minimal price</th>
    <th>Archive?</th>
  </thead>
TABLE_HEADER

for key in "${!live_timestamp_code_row_map[@]}"; do
  echo "${live_timestamp_code_row_map["${key}"]}"
done

echo '</table>'
