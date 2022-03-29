import React from 'react';
import { Segment, Grid, Header, List } from "semantic-ui-react";
import { Link } from 'react-router-dom';
import './footer.scss';

class Footer extends React.Component {

  render() {
    const { timestamp } = this.props;
    return (
      <Segment inverted vertical className='footer'>
        <Grid divided inverted stackable>
          <Grid.Row>
            <Grid.Column width={4}>
              <Header inverted as='h4' content='Use goodservice.io on' />
              <List link inverted>
                <List.Item>
                  <a href='https://www.amazon.com/dp/B09BNC892W/' target='_blank'>
                    Alexa
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://assistant.google.com/services/a/uid/0000008e2bd43866' target='_blank'>
                    Google Assistant
                  </a>
                </List.Item>
                <List.Item>
                  <a href='/slack'>
                    Slack
                  </a>
                </List.Item>
                <List.Item>
                  <Link to='/twitter'>Twitter</Link>
                </List.Item>
              </List>
            </Grid.Column>
            <Grid.Column width={8}>
              <Header inverted as='h4' content='Related' />
              <List link inverted>
                <List.Item>
                  <a href='https://www.medium.com/good-service' target='_blank'>
                    Good Service Blog
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://www.theweekendest.com' target='_blank'>
                    The Weekendest - Real-Time Map
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://www.subwaydle.com' target='_blank'>
                    Subwaydle - Daily Subway Puzzle Game
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://www.subwayridership.nyc' target='_blank'>
                    NYC Subway Ridership
                  </a>
                </List.Item>
              </List>
            </Grid.Column>
            <Grid.Column width={4}>
              <Header as='h4' inverted>
                Created by <a href='https://sunny.ng'>Sunny Ng</a>.
              </Header>
              <p>
                Last updated {timestamp && (new Date(timestamp * 1000)).toLocaleTimeString('en-US')}.<br />
                <a href='https://github.com/blahblahblah-/goodservice-v2'>Source code</a>.
              </p>
            </Grid.Column>
          </Grid.Row>
        </Grid>
      </Segment>
    );
  }


}

export default Footer;