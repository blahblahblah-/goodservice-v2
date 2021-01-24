import React from 'react';
import { Header } from "semantic-ui-react";

import TrainBullet from './trainBullet';

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
};

export const replaceTrainBulletsInParagraphs = (trains, array_of_strs) => {
  return array_of_strs.map((change, i) => {
    let tmp = [formatStation(change)];
    let matched;
    while (matched = tmp.find((c) => typeof c === 'string' && c.match(/\<[A-Z0-9]*\>/))) {
      const regexResult = matched.match(/\<([A-Z0-9]*)\>/);
      let j = tmp.indexOf(matched);
      const selectedTrain = trains[regexResult[1]];
      const selectedTrainBullet = (<TrainBullet name={selectedTrain.name} color={selectedTrain.color}
            textColor={selectedTrain.text_color} style={{display: "inline-block"}} key={selectedTrain.id} size='small' />);
      const parts = matched.split(regexResult[0]);
      let newMatched = parts.flatMap((x) => [x, selectedTrainBullet]);
      newMatched.pop();
      tmp[j] = newMatched;
      tmp = tmp.flat();
    }

    return (<Header as='h4' inverted key={i}>{tmp}</Header>);
  });
};

export const formatMinutes = (minutes, markDue) => {
  if (minutes > 1) {
    return `${minutes} mins`;
  }
  if (minutes > 0) {
    return `${minutes} min`;
  }
  if (markDue) {
    return 'Due';
  }
};

export const routingHash = (routing) => {
  return `${routing[0]}-${routing[routing.length-1]}-${routing.length}`;
}
