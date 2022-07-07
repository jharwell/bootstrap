source /opt/ros/noetic/setup.bash
source ~/.local/setup.bash

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.local/lib
export LOG4CXX_CONFIGURATION=$HOME/research/fordyca/log4cxx.xml
export ROS_HOSTNAME=$(hostname -I| tr -d '[:space:]')
export ROS_IP=$(hostname -I| tr -d '[:space:]')
