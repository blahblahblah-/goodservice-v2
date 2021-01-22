export const statusColor = (status) => {
  if (status == 'Good Service') {
    return 'green';
  } else if (status == 'Service Change') {
    return 'orange';
  } else if (status == 'Not Good') {
    return 'yellow';
  } else if (status == 'Slow') {
    return 'yellow';
  } else if (status == 'Delay') {
    return 'red';
  }
};

export const formatStation = (stationName) => {
  if (!stationName) {
    return;
  }
  return stationName.replace(/ - /g, "–")
}