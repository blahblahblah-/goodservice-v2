import React from 'react';
import { Header, Segment, Statistic, Grid } from "semantic-ui-react";

import { statusColor, formatStation, replaceTrainBulletsInParagraphs } from './utils';

class TrainModalDirectionPane extends React.Component {
  directionStatus() {
    const { train, direction } = this.props;
    if (['No Service', 'Not Scheduled'].includes(train.status)) {
      return train.status;
    }
    if (train.direction_statuses && train.direction_statuses[direction]) {
      return train.direction_statuses[direction];
    }
    return 'No Service';
  }

  renderServiceChanges() {
    const { train, trains, direction } = this.props;

    if (!train.service_change_summaries) {
      return;
    }

    const summaries = ['both', direction].map((key) => train.service_change_summaries[key]).flat();
    return replaceTrainBulletsInParagraphs(trains, summaries);
  }

  renderSummary() {
    const { train, direction } = this.props;
    let out = [];
    if (!train.service_summaries) {
      return out;
    }
    if (train.service_summaries[direction]) {
      out.push(<Header as='h4' inverted>{formatStation(train.service_summaries[direction])}</Header>)
    }
    return out;
  }

  render() {
    const { train } = this.props;
    return (
      <Segment basic>
        <Grid textAlign='center'>
          <Grid.Column>
            <Statistic.Group widths={1} color={statusColor(this.directionStatus())} size='small' inverted>
              <Statistic>
                <Statistic.Value>{ this.directionStatus() }</Statistic.Value>
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

export default TrainModalDirectionPane;