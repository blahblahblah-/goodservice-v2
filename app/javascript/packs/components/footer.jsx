import React from 'react';
import { Image, Segment, Grid, Header, List } from "semantic-ui-react";
import { Link } from 'react-router-dom';
import googleplay from "./images/googleplay.png";
import './footer.scss';

class Footer extends React.Component {

  render() {
    const { timestamp } = this.props;
    return (
      <Segment inverted vertical className='footer'>
        <Grid divided inverted stackable>
          <Grid.Row>
            <Grid.Column width={3}>
              <a href="https://apps.apple.com/us/app/the-weekendest-nyc-subway-map/id6476543418?itsct=apps_box_badge&amp;itscg=30200" style={{display: "inline-block", overflow: "hidden", borderRadius: "7.5px", width: "125px", height: "41.5px", marginTop:"12px", marginBottom: "12px"}}>
                <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1716681600" alt="Download on the App Store" style={{borderRadius: "7.5px", width: "125px", height: "41.5px"}} />
              </a>
              <a href="https://play.google.com/store/apps/details?id=io.goodservice.theweekendest" style={{display: "inline-block", overflow: "hidden", height: "41.5px", marginLeft:"12px", marginTop:"12px", marginBottom: "12px"}}>
                <Image src={googleplay} alt="Download on Google Play" style={{height: "41.5px"}}  />
              </a>
            </Grid.Column>
            <Grid.Column width={4}>
              <Header inverted as='h4' content='Use Subway Now on' />
              <List link inverted>
                <List.Item>
                  <a href='https://www.amazon.com/dp/B09BNC892W/' target='_blank'>
                    Alexa
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://tidbyt.com/pages/apps#live' target='_blank'>
                    Tidbyt
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
            <Grid.Column width={5}>
              <Header inverted as='h4' content='Related' />
              <List link inverted>
                <List.Item>
                  <a href='https://www.medium.com/good-service' target='_blank'>
                    Our blog
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://www.subwaynow.app' target='_blank'>
                    Subway Now - Real-Time Subway Map for NYC
                  </a>
                </List.Item>
                <List.Item>
                  <a href='https://www.subwaydle.com' target='_blank'>
                    Subwaydle - Daily Subway Puzzle Game
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
                <a href='https://github.com/blahblahblah-/goodservice-v2'>Source code</a>.<br />
                Subway Route Symbols ®: Metropolitan Transportation Authority. Used with permission.
              </p>
            </Grid.Column>
          </Grid.Row>
        </Grid>
      </Segment>
    );
  }


}

export default Footer;