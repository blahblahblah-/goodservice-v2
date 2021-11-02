import React from 'react';
import { Header, Segment, Statistic, Grid, Label } from "semantic-ui-react";

import TrainMap from './trainMap';
import { statusColor, formatStation, replaceTrainBulletsInParagraphs, twitterLink } from './utils';

import './trainModalOverviewPane.scss';

class TrainModalOverviewPane extends React.Component {
  renderDelays() {
    const { train } = this.props;
    let out = [];
    if (!train.delay_summaries) {
      return out;
    }
    if (train.delay_summaries["north"]) {
      out.push(<Header as='h4' inverted key="north">{formatStation(train.delay_summaries.north)}</Header>)
    }
    if (train.delay_summaries["south"]) {
      out.push(<Header as='h4' inverted key="south">{formatStation(train.delay_summaries.south)}</Header>)
    }

    if (out.length) {
      return (
        <Segment inverted basic>
          <Label attached='top' color='red'>DELAYS</Label>
          {
            out
          }
        </Segment>
      );
    }
  }

  renderServiceChanges() {
    const { train, trains } = this.props;

    if (!train.service_change_summaries) {
      return;
    }

    const summaries = Object.keys(train.service_change_summaries).map((key) => train.service_change_summaries[key]).flat();
    if (summaries.length) {
      return (
        <Segment inverted basic>
          <Label attached='top' color='orange'>SERVICE CHANGES</Label>
          {
            replaceTrainBulletsInParagraphs(trains, summaries)
          }
        </Segment>
      );
    }
  }

  renderServiceIrregularities() {
    const { train } = this.props;
    let out = [];
    if (!train.service_irregularity_summaries) {
      return out;
    }
    if (train.service_irregularity_summaries["north"]) {
      out.push(<Header as='h4' inverted key="north">{formatStation(train.service_irregularity_summaries.north)}</Header>)
    }
    if (train.service_irregularity_summaries["south"]) {
      out.push(<Header as='h4' inverted key="south">{formatStation(train.service_irregularity_summaries.south)}</Header>)
    }

    if (out.length) {
      return (
        <Segment inverted basic>
          <Label attached='top' color='yellow'>SERVICE IRREGULARITIES</Label>
          {
            out
          }
        </Segment>
      );
    }
  }

  render() {
    const { train, trains, stations } = this.props;
    return (
      <Segment basic className='train-modal-overview-pane'>
        <Grid textAlign='center' stackable>
          <Grid.Row>
            <Grid.Column className='map-cell' computer={4} tablet={6} mobile={6}>
              <TrainMap trains={trains} train={train} stations={stations} routings={train.actual_routings} scheduledRoutings={train.scheduled_routings} />
            </Grid.Column>
            <Grid.Column className='status-cell' computer={12} tablet={10} mobile={10}>
              <Statistic.Group widths={1} color={ statusColor(train.status) } size='small' inverted>
                <Statistic>
                  <Statistic.Value>{train.status}</Statistic.Value>
                  <Statistic.Label>
                    Status
                    { twitterLink(train.id) }
                  </Statistic.Label>
                </Statistic>
              </Statistic.Group>
              {
                this.renderDelays()
              }
              {
                this.renderServiceChanges()
              }
              {
                this.renderServiceIrregularities()
              }
            </Grid.Column>
            <Grid.Column width={4} className='mobile-map-cell'>
              <TrainMap trains={trains} train={train} stations={stations} routings={train.actual_routings} scheduledRoutings={train.scheduled_routings} />
            </Grid.Column>
         </Grid.Row>
        </Grid>
      </Segment>
    )
  }
}

export default TrainModalOverviewPane;