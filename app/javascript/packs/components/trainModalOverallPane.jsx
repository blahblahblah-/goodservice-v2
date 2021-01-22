import React from 'react';
import { Header, Segment, Statistic, Grid } from "semantic-ui-react";

import TrainBullet from './trainBullet';
import { statusColor, formatStation } from './utils';

class TrainModalOverallPane extends React.Component {
  renderServiceChanges() {
    const { train, trains } = this.props;

    if (!train.service_change_summaries) {
      return;
    }

    const summaries = Object.keys(train.service_change_summaries).map((key) => train.service_change_summaries[key]).flat();
    return summaries.map((change, i) => {
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
  }

  renderSummary() {
    const { train } = this.props;
    let out = [];
    if (!train.service_summaries) {
      return out;
    }
    if (train.service_summaries["south"]) {
      out.push(<Header as='h4' inverted key="south">{formatStation(train.service_summaries.south)}</Header>)
    }
    if (train.service_summaries["north"]) {
      out.push(<Header as='h4' inverted key="north">{formatStation(train.service_summaries.north)}</Header>)
    }
    return out;
  }

  render() {
    const { train } = this.props;
    return (
      <Segment basic>
        <Grid textAlign='center'>
          <Grid.Column>
            <Statistic.Group widths={1} color={statusColor(train.status)} size='small' inverted>
              <Statistic>
                <Statistic.Value>{train.status}</Statistic.Value>
                <Statistic.Label>Status</Statistic.Label>
              </Statistic>
            </Statistic.Group>
            {
              this.renderServiceChanges()
            }
            {
              this.renderSummary()
            }
          </Grid.Column>
        </Grid>
      </Segment>
    )
  }
}

export default TrainModalOverallPane;