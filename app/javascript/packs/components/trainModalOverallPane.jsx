import React from 'react';
import { Header, Segment, Statistic, Grid } from "semantic-ui-react";

import TrainMap from './trainMap';
import { statusColor, formatStation, replaceTrainBulletsInParagraphs } from './utils';

import './trainModalOverallPane.scss';

class TrainModalOverallPane extends React.Component {
  renderServiceChanges() {
    const { train, trains } = this.props;

    if (!train.service_change_summaries) {
      return;
    }

    const summaries = Object.keys(train.service_change_summaries).map((key) => train.service_change_summaries[key]).flat();
    return replaceTrainBulletsInParagraphs(trains, summaries);
  }

  renderSummary() {
    const { train } = this.props;
    let out = [];
    if (!train.service_summaries) {
      return out;
    }
    if (train.service_summaries["north"]) {
      out.push(<Header as='h4' inverted key="north">{formatStation(train.service_summaries.north)}</Header>)
    }
    if (train.service_summaries["south"]) {
      out.push(<Header as='h4' inverted key="south">{formatStation(train.service_summaries.south)}</Header>)
    }
    return out;
  }

  render() {
    const { train, trains } = this.props;
    return (
      <Segment basic className='train-modal-overall-pane'>
        <Grid textAlign='center' stackable>
          <Grid.Row>
            <Grid.Column width={4} className='map-cell'>
              <TrainMap trains={trains} train={train} routings={train.actual_routings} />
            </Grid.Column>
            <Grid.Column width={12}>
              <Statistic.Group widths={1} color={ statusColor(train.status) } size='small' inverted>
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
            <Grid.Column width={4} className='mobile-map-cell'>
              <TrainMap trains={trains} train={train} routings={train.actual_routings} />
            </Grid.Column>
         </Grid.Row>
        </Grid>
      </Segment>
    )
  }
}

export default TrainModalOverallPane;