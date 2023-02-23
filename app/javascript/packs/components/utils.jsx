import React from 'react';
import { Header, Icon } from "semantic-ui-react";

import TrainBullet from './trainBullet';

const TWITTER_FEEDS_EXCLUDED_TRAINS = ['FS', 'GS', 'SI'];
const TWITTER_FEEDS_MAPPED_TRAINS = {
  '6X': '6',
  '7X': '7',
  'FX': 'F',
  'H': 'A',
}

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

export const formatMinutes = (minutes, markDue, prefixPositiveValues) => {
  if (minutes > 0) {
    if (prefixPositiveValues) {
      return `+${minutes} min`;
    }
    return `${minutes} min`;
  }
  if (markDue) {
    return 'Due';
  }
  return `${minutes} min`;
};

export const routingHash = (routing) => {
  return `${routing[0]}-${routing[routing.length-1]}-${routing.length}`;
}

export const twitterLink = (trainId) => {
  if (TWITTER_FEEDS_EXCLUDED_TRAINS.includes(trainId)) {
    return;
  }
  const twitterTrainId = TWITTER_FEEDS_MAPPED_TRAINS[trainId] || trainId;
  return (
    <div className="twitter-link">
      <a href={`https://twitter.com/goodservice_${twitterTrainId}`} target="_blank">
        Follow @goodservice_{twitterTrainId}
        <Icon name='twitter' color='blue' />
      </a>
    </div>
  );
};

export const hexToRgb = (hex) => {
  var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : null;
}
