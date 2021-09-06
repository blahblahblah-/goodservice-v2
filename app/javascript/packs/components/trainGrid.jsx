import React from 'react';
import { Grid, Header } from "semantic-ui-react";
import { Link } from 'react-router-dom';
import { groupBy } from 'lodash';

import Train from './train';
import TrainBullet from './trainBullet';

import './trainGrid.scss';

const STATUSES = {
  'Delay': 'red',
  'No Service': 'black',
  'Service Change': 'orange',
  'Slow': 'yellow',
  'Not Good': 'yellow',
  'Good Service': 'green',
  'Not Scheduled': 'black'
};


class TrainGrid extends React.Component {

  render() {
    const { selectedTrain, trains, stations } = this.props;
    const trainKeys = Object.keys(trains);
    let groups = groupBy(trains, 'status');
    const stationsObj = {};
    stations.forEach((s) => {
      stationsObj[s.id] = s;
    })
    return (
      <React.Fragment>
        <Grid columns={6} doubling className='train-grid'>
        {
          stations && trainKeys.map(trainId => trains[trainId]).sort((a, b) => {
            const nameA = `${a.name} ${a.alternate_name}`;
            const nameB = `${b.name} ${b.alternate_name}`;
            if (nameA < nameB) {
              return -1;
            }
            if (nameA > nameB) {
              return 1;
            }
            return 0;
          }).map(train => {
            const visible = train.visible || train.status !== 'Not Scheduled';
            return (
              <Grid.Column key={train.id} style={{display: (visible ? 'block' : 'none')}}>
                <Train train={train} trains={trains} stations={stationsObj} selected={selectedTrain === train.id} />
              </Grid.Column>)
          })
        }
        </Grid>
        <Grid className='mobile-train-grid'>
          {
            Object.keys(STATUSES).filter((s) => groups[s]).map((status) => {
              return (
                <React.Fragment key={status}>
                  <Grid.Row columns={1} className='train-status-row'>
                    <Grid.Column><Header size='small' color={STATUSES[status]} inverted>{status}</Header></Grid.Column>
                  </Grid.Row>
                  <Grid.Row columns={6} textAlign='center'>
                    {
                      groups[status].map(train => {
                        const visible = train.visible || train.status !== 'Not Scheduled';
                        return (
                          <Grid.Column key={train.name + train.alternate_name} style={{display: (visible ? 'block' : 'none')}}>
                            <Link to={`/trains/${train.id}`}>
                              <TrainBullet name={train.name} alternateName={train.alternate_name && train.alternate_name[0]} color={train.color} size='small'
                                              textColor={train.text_color} style={{ float: 'left' }} />
                            </Link>
                          </Grid.Column>
                        )
                      })
                    }
                  </Grid.Row>
                </React.Fragment>
              )
            })
          }
        </Grid>
      </React.Fragment>
    );
  }
}

export default TrainGrid;